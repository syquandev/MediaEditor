//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalServiceKit
import SignalCoreKit

@objc public extension UIApplication {

    var frontmostViewControllerIgnoringAlerts: UIViewController? {
        guard let window = CurrentAppContext().mainWindow else {
            return nil
        }
        return findFrontmostViewController(ignoringAlerts: true, window: window)
    }

    var frontmostViewController: UIViewController? {
        guard let window = CurrentAppContext().mainWindow else {
            return nil
        }
        return findFrontmostViewController(ignoringAlerts: false, window: window)
    }

    func findFrontmostViewController(ignoringAlerts: Bool, window: UIWindow) -> UIViewController? {
        Logger.verbose("findFrontmostViewController: \(window)")
        guard let viewController = window.rootViewController else {
            owsFailDebug("Missing root view controller.")
            return nil
        }
        return viewController.findFrontmostViewController(ignoringAlerts)
    }

    func openSystemSettings() {
        open(URL(string: UIApplication.openSettingsURLString)!, options: [:])
    }
}
