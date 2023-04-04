//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalServiceKit
import SignalCoreKit

@objc
public class AppEnvironment: NSObject {

    private static var _shared: AppEnvironment = AppEnvironment()

    @objc
    public class var shared: AppEnvironment {
        get {
            return _shared
        }
        set {
            guard CurrentAppContext().isRunningTests else {
                owsFailDebug("Can only switch environments in tests.")
                return
            }

            _shared = newValue
        }
    }

    @objc
    public var accountManagerRef: AccountManager


    @objc
    public var windowManagerRef: OWSWindowManager = OWSWindowManager()

    private override init() {
        self.accountManagerRef = AccountManager()

        super.init()

        SwiftSingletons.register(self)
    }

    @objc
    public func setup() {
    }
}
