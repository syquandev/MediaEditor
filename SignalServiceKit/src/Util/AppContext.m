//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "AppContext.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const OWSApplicationDidEnterBackgroundNotification = @"OWSApplicationDidEnterBackgroundNotification";
NSString *const OWSApplicationWillEnterForegroundNotification = @"OWSApplicationWillEnterForegroundNotification";
NSString *const OWSApplicationWillResignActiveNotification = @"OWSApplicationWillResignActiveNotification";
NSString *const OWSApplicationDidBecomeActiveNotification = @"OWSApplicationDidBecomeActiveNotification";

NSString *NSStringForUIApplicationState(UIApplicationState value)
{
    switch (value) {
        case UIApplicationStateActive:
            return @"UIApplicationStateActive";
        case UIApplicationStateInactive:
            return @"UIApplicationStateInactive";
        case UIApplicationStateBackground:
            return @"UIApplicationStateBackground";
    }
}

static id<AppContext> currentAppContext = nil;

id<AppContext> CurrentAppContext(void)
{

    return currentAppContext;
}

void SetCurrentAppContext(id<AppContext> appContext)
{
    currentAppContext = appContext;
}

#ifdef TESTABLE_BUILD
void ClearCurrentAppContextForTests()
{
    currentAppContext = nil;
}
#endif

void ExitShareExtension(void)
{
    exit(0);
}

NS_ASSUME_NONNULL_END
