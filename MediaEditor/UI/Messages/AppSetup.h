//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>
#import <SignalCoreKit/SignalCoreKit-Swift.h>
#import <SignalServiceKit/OWSBackgroundTask.h>
#import <SignalServiceKit/StorageCoordinator.h>
#import <SignalServiceKit/OWSFileSystem.h>
#import <SignalServiceKit/OWSDevice.h>
#import <SignalServiceKit/SSKEnvironment.h>
#import <SignalServiceKit/OWSIdentityManager.h>
#import <SignalServiceKit/ExperienceUpgrade.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MobileCoinHelper;
@protocol PaymentsEvents;
@protocol WebSocketFactory;

// This is _NOT_ a singleton and will be instantiated each time that the SAE is used.
@interface AppSetup : NSObject

+ (void)appSpecificSingletonBlock:(NS_NOESCAPE dispatch_block_t)appSpecificSingletonBlock
                       migrationCompletion:(void (^)(NSError *_Nullable error))migrationCompletion
NS_SWIFT_NAME(setupEnvironment(appSpecificSingletonBlock:migrationCompletion:));

@end

NS_ASSUME_NONNULL_END

