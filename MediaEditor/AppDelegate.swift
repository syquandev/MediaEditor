//
//  AppDelegate.swift
//  MediaEditor
//
//  Created by Quan on 20/02/2023.
//

import UIKit
import SignalServiceKit
import SignalCoreKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let vc = LoadingViewController()
        self.window?.rootViewController = vc
        self.window?.makeKeyAndVisible()
        
        AppSetup.setupEnvironment(
            appSpecificSingletonBlock: {
                
            },
            migrationCompletion: { [weak self] error in
                if let error = error {
                    // TODO: Maybe notify that you should open the main app.
                    owsFailDebug("Error \(error)")
                    return
                }
            }
        )
        
//        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
//            [self.tsAccountManager setIsOnboarded:NO transaction:transaction];
//        });
//
//        databaseStorag

        return true
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
//        if (CurrentAppContext().isRunningTests) {
//            return UIInterfaceOrientationMask.portrait
//        }

        var rootViewController = UIViewController()
        if rootViewController == (self.window?.rootViewController)! {
            return UIDevice.current.defaultSupportedOrientations;
        }
        
        return rootViewController.supportedInterfaceOrientations
    }
}

