//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalServiceKit

// MARK: - NSObject

@objc
public extension NSObject {

    final var accountManager: AccountManager {
        AppEnvironment.shared.accountManagerRef
    }

    static var accountManager: AccountManager {
        AppEnvironment.shared.accountManagerRef
    }

    final var deviceSleepManager: DeviceSleepManager {
        .shared
    }

    static var deviceSleepManager: DeviceSleepManager {
        .shared
    }

    final var signalApp: SignalApp {
        .shared()
    }

    static var signalApp: SignalApp {
        .shared()
    }

    var windowManager: OWSWindowManager {
        AppEnvironment.shared.windowManagerRef
    }

    static var windowManager: OWSWindowManager {
        AppEnvironment.shared.windowManagerRef
    }
}

// MARK: - Obj-C Dependencies

public extension Dependencies {
    var accountManager: AccountManager {
        AppEnvironment.shared.accountManagerRef
    }

    static var accountManager: AccountManager {
        AppEnvironment.shared.accountManagerRef
    }

    var deviceSleepManager: DeviceSleepManager {
        .shared
    }

    static var deviceSleepManager: DeviceSleepManager {
        .shared
    }

    var signalApp: SignalApp {
        .shared()
    }

    static var signalApp: SignalApp {
        .shared()
    }

    var windowManager: OWSWindowManager {
        AppEnvironment.shared.windowManagerRef
    }

    static var windowManager: OWSWindowManager {
        AppEnvironment.shared.windowManagerRef
    }
}

//@objc
//public extension OWSWindowManager {
//    static var shared: OWSWindowManager {
//        AppEnvironment.shared.windowManagerRef
//    }
//}
