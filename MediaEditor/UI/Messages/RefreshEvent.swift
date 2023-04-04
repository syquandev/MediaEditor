//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation

// This class can be used to coordinate the refresh of a
// value obtained from the network.
@objc
public class RefreshEvent: NSObject {

    public typealias Block = () -> Void

    private let block: Block

    private let refreshInterval: TimeInterval

    private var refreshTimer: Timer?

    // The block will be performed with a rough frequency of refreshInterval.
    //
    // It will not be performed if the app isn't ready, the user isn't registered,
    // if the app isn't the main app, if the app isn't active.
    //
    // It will also be performed immediately if any of the conditions change.
    public required init(refreshInterval: TimeInterval,
                         block: @escaping Block) {
        self.refreshInterval = refreshInterval
        self.block = block

        super.init()
    }

    private var canFire: Bool {
        return true
    }

    private func fireEvent() {
        guard canFire else {
            return
        }
        block()
    }

    @objc
    private func didEnterBackground() {
        ensureRefreshTimer()
    }

    @objc
    private func didBecomeActive() {
        ensureRefreshTimer()
    }

    private func ensureRefreshTimer() {
        guard canFire else {
            stopRefreshTimer()
            return
        }
        startRefreshTimer()
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func startRefreshTimer() {
        guard refreshTimer == nil else {
            return
        }

        fireEvent()
    }
}
