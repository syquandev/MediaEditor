//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

//#import <SignalServiceKit/SSKEnvironment.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class OWSPreferences;

@protocol OWSProximityMonitoringManager;

/**
 *
 * Environment is a data and data accessor class.
 * It handles application-level component wiring in order to support mocks for testing.
 * It also handles network configuration for testing/deployment server configurations.
 *
 **/
// TODO: Rename to SMGEnvironment?
@interface Environment : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)preferences:(OWSPreferences *)preferences;

@property (nonatomic, readonly) OWSPreferences *preferencesRef;

@property (class, nonatomic) Environment *shared;

#ifdef TESTABLE_BUILD
// Should only be called by tests.
+ (void)clearSharedForTests;
#endif

@end
