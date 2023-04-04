//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

#import "MainAppContext.h"
#import <MediaEditor-Swift.h>
#import <SignalCoreKit/Threading.h>
#import "Environment.h"
#import <MediaEditor-Swift.h>
#import <SignalServiceKit/OWSIdentityManager.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const ReportedApplicationStateDidChangeNotification = @"ReportedApplicationStateDidChangeNotification";

@interface MainAppContext ()

@property (nonatomic, nullable) NSMutableArray<AppActiveBlock> *appActiveBlocks;

@property (nonatomic, readonly) UIApplicationState mainApplicationStateOnLaunch;

@end

#pragma mark -

@implementation MainAppContext

@synthesize mainWindow = _mainWindow;
@synthesize appLaunchTime = _appLaunchTime;
@synthesize buildTime = _buildTime;
@synthesize reportedApplicationState = _reportedApplicationState;

- (instancetype)init
{
    self = [super init];

    if (!self) {
        return self;
    }

    self.reportedApplicationState = UIApplicationStateInactive;

    _appLaunchTime = [NSDate new];
    _mainApplicationStateOnLaunch = [UIApplication sharedApplication].applicationState;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillTerminate:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];

    // We can't use OWSSingletonAssert() since it uses the app context.

    self.appActiveBlocks = [NSMutableArray new];

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notifications

- (UIApplicationState)reportedApplicationState
{
    @synchronized(self) {
        return _reportedApplicationState;
    }
}

- (void)setReportedApplicationState:(UIApplicationState)reportedApplicationState
{
    @synchronized(self) {
        if (_reportedApplicationState == reportedApplicationState) {
            return;
        }
        _reportedApplicationState = reportedApplicationState;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:ReportedApplicationStateDidChangeNotification
                                                        object:nil
                                                      userInfo:nil];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    self.reportedApplicationState = UIApplicationStateInactive;

    [BenchManager benchWithTitle:@"Slow post WillEnterForeground"
                 logIfLongerThan:0.01
                 logInProduction:YES
                           block:^{
                               [NSNotificationCenter.defaultCenter
                                   postNotificationName:OWSApplicationWillEnterForegroundNotification
                                                 object:nil];
                           }];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    self.reportedApplicationState = UIApplicationStateBackground;

    [BenchManager benchWithTitle:@"Slow post DidEnterBackground"
                 logIfLongerThan:0.01
                 logInProduction:YES
                           block:^{
                               [NSNotificationCenter.defaultCenter
                                   postNotificationName:OWSApplicationDidEnterBackgroundNotification
                                                 object:nil];
                           }];
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    self.reportedApplicationState = UIApplicationStateInactive;

    [BenchManager benchWithTitle:@"Slow post WillResignActive"
                 logIfLongerThan:0.01
                 logInProduction:YES
                           block:^{
                               [NSNotificationCenter.defaultCenter
                                   postNotificationName:OWSApplicationWillResignActiveNotification
                                                 object:nil];
                           }];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    self.reportedApplicationState = UIApplicationStateActive;

    [BenchManager benchWithTitle:@"Slow post DidBecomeActive"
                 logIfLongerThan:0.01
                 logInProduction:YES
                           block:^{
                               [NSNotificationCenter.defaultCenter
                                   postNotificationName:OWSApplicationDidBecomeActiveNotification
                                                 object:nil];
                           }];

    [self runAppActiveBlocks];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
}

#pragma mark -

- (BOOL)isMainApp
{
    return YES;
}

- (BOOL)isMainAppAndActive
{
    return [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
}

- (BOOL)isNSE
{
    return NO;
}

- (BOOL)isRTL
{
    static BOOL isRTL = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        isRTL = [[UIApplication sharedApplication] userInterfaceLayoutDirection]
            == UIUserInterfaceLayoutDirectionRightToLeft;
    });
    return isRTL;
}

- (CGFloat)statusBarHeight
{
    return [UIApplication sharedApplication].statusBarFrame.size.height;
}

- (BOOL)isInBackground
{
    return self.reportedApplicationState == UIApplicationStateBackground;
}

- (BOOL)isAppForegroundAndActive
{
    return self.reportedApplicationState == UIApplicationStateActive;
}

- (UIBackgroundTaskIdentifier)beginBackgroundTaskWithExpirationHandler:
    (BackgroundTaskExpirationHandler)expirationHandler
{
    return [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:expirationHandler];
}

- (void)endBackgroundTask:(UIBackgroundTaskIdentifier)backgroundTaskIdentifier
{
    [UIApplication.sharedApplication endBackgroundTask:backgroundTaskIdentifier];
}

- (void)ensureSleepBlocking:(BOOL)shouldBeBlocking blockingObjectsDescription:(NSString *)blockingObjectsDescription
{
    if (UIApplication.sharedApplication.isIdleTimerDisabled != shouldBeBlocking) {
    }
    UIApplication.sharedApplication.idleTimerDisabled = shouldBeBlocking;
}

- (void)setMainAppBadgeNumber:(NSInteger)value
{
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:value];
}

- (nullable UIViewController *)frontmostViewController
{
    return UIApplication.sharedApplication.frontmostViewControllerIgnoringAlerts;
}

- (void)openSystemSettings
{
    [UIApplication.sharedApplication openSystemSettings];
}

- (void)openURL:(NSURL *)url completion:(void (^__nullable)(BOOL success))completion
{
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:completion];
}

- (BOOL)isRunningTests
{
    return getenv("runningTests_dontStartApp");
}

- (NSDate *)buildTime
{
    if (!_buildTime) {
        NSInteger buildTimestamp =
        [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"BuildDetails"][@"Timestamp"] integerValue];

        if (buildTimestamp == 0) {
            _buildTime = [NSDate distantFuture];
        } else {
            _buildTime = [NSDate dateWithTimeIntervalSince1970:buildTimestamp];
        }
    }

    return _buildTime;
}

- (CGRect)frame
{
    return self.mainWindow.frame;
}

- (UIInterfaceOrientation)interfaceOrientation
{
    return [UIApplication sharedApplication].statusBarOrientation;
}

- (void)setNetworkActivityIndicatorVisible:(BOOL)value
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:value];
}

#pragma mark -

- (void)runNowOrWhenMainAppIsActive:(AppActiveBlock)block
{
    DispatchMainThreadSafe(^{
        [self.appActiveBlocks addObject:block];
    });
}

- (void)runAppActiveBlocks
{
}

- (id<SSKKeychainStorage>)keychainStorage
{
    return [SSKDefaultKeychainStorage shared];
}

- (NSString *)appDocumentDirectoryPath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentDirectoryURL =
        [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    return [documentDirectoryURL path];
}

- (NSString *)appSharedDataDirectoryPath
{
    NSURL *groupContainerDirectoryURL =
        [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:TSConstants.applicationGroup];
    return [groupContainerDirectoryURL path];
}

- (NSString *)appDatabaseBaseDirectoryPath
{
    return self.appSharedDataDirectoryPath;
}

- (NSUserDefaults *)appUserDefaults
{
    return [[NSUserDefaults alloc] initWithSuiteName:TSConstants.applicationGroup];
}

- (BOOL)canPresentNotifications
{
    return YES;
}

- (BOOL)shouldProcessIncomingMessages
{
    return YES;
}

- (BOOL)hasUI
{
    return YES;
}

- (BOOL)didLastLaunchNotTerminate
{
    return SignalApp.shared.didLastLaunchNotTerminate;
}

- (BOOL)hasActiveCall
{
    return NO;
}

- (NSString *)debugLogsDirPath
{
    NSString * kURLSchemeSGNLKey;
    return kURLSchemeSGNLKey;
}

@end

NS_ASSUME_NONNULL_END
