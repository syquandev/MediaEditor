//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "VersionMigrations.h"
#import "Environment.h"
#import <MediaEditor-Swift.h>
#import <SignalServiceKit/AppContext.h>
#import <SignalServiceKit/AppVersion.h>
#import <SignalServiceKit/NSUserDefaults+OWS.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

#define NEEDS_TO_REGISTER_PUSH_KEY @"Register For Push"
#define NEEDS_TO_REGISTER_ATTRIBUTES @"Register Attributes"

@implementation VersionMigrations

#pragma mark - Utility methods

+ (void)performUpdateCheckWithCompletion:(VersionMigrationCompletion)completion
{
    NSString *_Nullable lastCompletedLaunchAppVersion = AppVersion.shared.lastCompletedLaunchAppVersion;
    NSString *releaseVersion = AppVersion.shared.currentAppReleaseVersion;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{ [self.databaseStorage runGrdbSchemaMigrationsWithCompletion:completion]; });
}

+ (BOOL)isVersion:(NSString *)thisVersionString
          atLeast:(NSString *)openLowerBoundVersionString
      andLessThan:(NSString *)closedUpperBoundVersionString
{
    return [self isVersion:thisVersionString atLeast:openLowerBoundVersionString] &&
        [self isVersion:thisVersionString lessThan:closedUpperBoundVersionString];
}

+ (BOOL)isVersion:(NSString *)thisVersionString atLeast:(NSString *)thatVersionString
{
    return [thisVersionString compare:thatVersionString options:NSNumericSearch] != NSOrderedAscending;
}

+ (BOOL)isVersion:(NSString *)thisVersionString lessThan:(NSString *)thatVersionString
{
    return [thisVersionString compare:thatVersionString options:NSNumericSearch] == NSOrderedAscending;
}

@end

NS_ASSUME_NONNULL_END
