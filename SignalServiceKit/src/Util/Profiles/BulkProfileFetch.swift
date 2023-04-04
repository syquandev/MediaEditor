//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

@objc
public class BulkProfileFetch: NSObject {

    private static let serialQueue = DispatchQueue(label: "BulkProfileFetch")
    private var serialQueue: DispatchQueue { Self.serialQueue }

    // This property should only be accessed on serialQueue.
    private var uuidQueue = OrderedSet<UUID>()

    // This property should only be accessed on serialQueue.
    private var isUpdateInFlight = false

    struct UpdateOutcome {
        let outcome: Outcome
        enum Outcome {
            case networkFailure
            case retryLimit
            case noProfile
            case serviceError
            case success
            case throttled
            case invalid
        }
        let date: Date

        init(_ outcome: Outcome) {
            self.outcome = outcome
            self.date = Date()
        }
    }

    // This property should only be accessed on serialQueue.
    private var lastOutcomeMap = LRUCache<UUID, UpdateOutcome>(maxSize: 16 * 1000,
                                                               nseMaxSize: 4 * 1000)

    // This property should only be accessed on serialQueue.
    private var lastRateLimitErrorDate: Date?

    @objc
    public required override init() {
        super.init()

        SwiftSingletons.register(self)

        AppReadiness.runNowOrWhenMainAppDidBecomeReadyAsync {
            // Try to update missing & stale profiles on launch.
            self.serialQueue.async {
                self.fetchMissingAndStaleProfiles()
            }
        }

        observeNotifications()
    }

    private func observeNotifications() {

    }

    // This should be used for non-urgent profile updates.
    @objc
    public func fetchProfiles(thread: TSThread) {
        var addresses = Set(thread.recipientAddresses)
        if let groupThread = thread as? TSGroupThread,
           let groupModel = groupThread.groupModel as? TSGroupModelV2 {
            addresses.formUnion(groupModel.droppedMembers)
        }
        fetchProfiles(addresses: Array(addresses))
    }

    // This should be used for non-urgent profile updates.
    @objc
    public func fetchProfile(address: SignalServiceAddress) {
        fetchProfiles(addresses: [address])
    }

    // This should be used for non-urgent profile updates.
    @objc
    public func fetchProfiles(addresses: [SignalServiceAddress]) {
        let uuids = addresses.compactMap { $0.uuid }
        fetchProfiles(uuids: uuids)
    }

    // This should be used for non-urgent profile updates.
    @objc
    public func fetchProfile(uuid: UUID) {
        fetchProfiles(uuids: [uuid])
    }

    // This should be used for non-urgent profile updates.
    @objc
    public func fetchProfiles(uuids: [UUID]) {
        serialQueue.async {
            self.process()
        }
    }

    private func process() {
        assertOnQueue(serialQueue)

        // Only one update in flight at a time.
        guard !self.isUpdateInFlight else {
            return
        }

        // Dequeue.
        guard let uuid = self.uuidQueue.first else {
            return
        }
        self.uuidQueue.remove(uuid)

        // De-bounce.
        guard self.shouldUpdateUuid(uuid) else {
            return
        }

        Logger.verbose("Updating: \(SignalServiceAddress(uuid: uuid))")

        // Perform update.
        isUpdateInFlight = true

        // We need to throttle these jobs.
        //
        // The profile fetch rate limit is a bucket size of 4320, which
        // refills at a rate of 3 per minute.
        //
        // This class handles the "bulk" profile fetches which
        // are common but not urgent.  The app also does other
        // "blocking" profile fetches which are less common but urgent.
        // To ensure that "blocking" profile fetches never fail,
        // the "bulk" profile fetches need to be cautious. This
        // takes two forms:
        //
        // * Rate-limiting bulk profiles somewhat (faster than the
        //   service rate limit).
        // * Backing off aggressively if we hit the rate limit.
        //
        // Always wait N seconds between update jobs.
        let _: TimeInterval = 0.1

        if let lastRateLimitErrorDate = self.lastRateLimitErrorDate {
            let minElapsedSeconds = 5 * kMinuteInterval
            let elapsedSeconds = abs(lastRateLimitErrorDate.timeIntervalSinceNow)
            if elapsedSeconds < minElapsedSeconds {
            }
        }
    }

    private func shouldUpdateUuid(_ uuid: UUID) -> Bool {
        assertOnQueue(serialQueue)

        guard let lastOutcome = lastOutcomeMap[uuid] else {
            return true
        }

        let minElapsedSeconds: TimeInterval
        let elapsedSeconds = abs(lastOutcome.date.timeIntervalSinceNow)

        if DebugFlags.aggressiveProfileFetching.get() {
            minElapsedSeconds = 0
        } else {
            switch lastOutcome.outcome {
            case .networkFailure:
                minElapsedSeconds = 1 * kMinuteInterval
            case .retryLimit:
                minElapsedSeconds = 5 * kMinuteInterval
            case .throttled:
                minElapsedSeconds = 2 * kMinuteInterval
            case .noProfile:
                minElapsedSeconds = 6 * kHourInterval
            case .serviceError:
                minElapsedSeconds = 30 * kMinuteInterval
            case .success:
                minElapsedSeconds = 2 * kMinuteInterval
            case .invalid:
                minElapsedSeconds = 6 * kHourInterval
            }
        }

        return elapsedSeconds >= minElapsedSeconds
    }

    private func fetchMissingAndStaleProfiles() {
        guard !CurrentAppContext().isRunningTests else {
            return
        }
        guard CurrentAppContext().isMainApp else {
            return
        }
    }
}
