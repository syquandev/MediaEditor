//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

@objc
public class BulkUUIDLookup: NSObject {

    private let serialQueue = DispatchQueue(label: "BulkUUIDLookup")

    // This property should only be accessed on serialQueue.
    private var phoneNumberQueue = Set<String>()

    // This property should only be accessed on serialQueue.
    private var isUpdateInFlight = false

    struct UpdateOutcome {
        let outcome: Outcome
        enum Outcome {
            case networkFailure
            case retryLimit
            case serviceError
            case success
            case unknownError
        }
        let date: Date

        init(_ outcome: Outcome) {
            self.outcome = outcome
            self.date = Date()
        }
    }

    // This property should only be accessed on serialQueue.
    private var lastOutcomeMap = LRUCache<String, UpdateOutcome>(maxSize: 16 * 1000,
                                                                 nseMaxSize: 4 * 1000)

    // This property should only be accessed on serialQueue.
    // Next CDS fetch may be performed on or after this date
    private var rateLimitExpirationDate: Date = .distantPast

    @objc
    public required override init() {
        super.init()

        SwiftSingletons.register(self)

        observeNotifications()
    }

    private func observeNotifications() {

    }

    // This should be used for non-urgent uuid lookups.
    @objc
    public func lookupUuids(phoneNumbers: [String]) {
        serialQueue.async {
            self.phoneNumberQueue.formUnion(phoneNumbers)
            self.process()
        }
    }

    private func process() {
        assertOnQueue(serialQueue)

        guard !CurrentAppContext().isRunningTests else { return }

        guard CurrentAppContext().isMainApp else {
            return
        }

        // Only one update in flight at a time.
        guard !self.isUpdateInFlight else {
            return
        }

        // Build batch.
        let phoneNumbers = phoneNumberQueue.filter { self.shouldUpdatePhoneNumber($0) }
        phoneNumberQueue.removeAll()

        guard !phoneNumbers.isEmpty else {
            return
        }

        // De-bounce.

        Logger.verbose("Updating: \(phoneNumbers)")
    }

    private func shouldUpdatePhoneNumber(_ phoneNumber: String) -> Bool {
        assertOnQueue(serialQueue)

        guard SignalServiceAddress(phoneNumber: phoneNumber).uuid == nil else {
            return false
        }

        // Skip if we're rate limited
        if rateLimitExpirationDate.timeIntervalSinceNow > 0 {
            return false
        }

        guard let lastOutcome = lastOutcomeMap[phoneNumber] else {
            return true
        }

        let minElapsedSeconds: TimeInterval
        let elapsedSeconds = lastOutcome.date.timeIntervalSinceNow

        switch lastOutcome.outcome {
        case .networkFailure:
            minElapsedSeconds = 1 * kMinuteInterval
        case .retryLimit:
            minElapsedSeconds = 15 * kMinuteInterval
        case .serviceError:
            minElapsedSeconds = 30 * kMinuteInterval
        case .unknownError:
            minElapsedSeconds = 60 * kMinuteInterval
        case .success:
            minElapsedSeconds = 60 * kMinuteInterval
        }

        return elapsedSeconds >= minElapsedSeconds
    }
}
