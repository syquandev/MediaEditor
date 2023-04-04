//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

#import "SignalApp.h"
#import "ConversationViewController.h"
#import <MediaEditor-Swift.h>
#import <SignalCoreKit/Threading.h>
#import "DebugLogger.h"
#import "Environment.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>
#import <SignalServiceKit/TSContactThread.h>
#import <SignalServiceKit/TSGroupThread.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const kNSUserDefaults_DidTerminateKey = @"kNSUserDefaults_DidTerminateKey";

@interface SignalApp ()

@property (nonatomic, nullable, weak) ConversationSplitViewController *conversationSplitViewController;
@property (nonatomic) BOOL hasInitialRootViewController;

@end

#pragma mark -

@implementation SignalApp

+ (instancetype)shared
{
    static SignalApp *sharedApp = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedApp = [[self alloc] initDefault];
    });
    return sharedApp;
}

- (instancetype)initDefault
{
    self = [super init];

    if (!self) {
        return self;
    }

    [self handleCrashDetection];

    return self;
}

#pragma mark - Crash Detection

- (void)handleCrashDetection
{
    NSUserDefaults *userDefaults = CurrentAppContext().appUserDefaults;
#if TESTABLE_BUILD
    // Ignore "crashes" in DEBUG builds; applicationWillTerminate
    // will rarely be called during development.
#else
    _didLastLaunchNotTerminate = [userDefaults objectForKey:kNSUserDefaults_DidTerminateKey] != nil;
#endif
    // Very soon after every launch, we set this key.
    // We clear this key when the app terminates in
    // an orderly way.  Therefore if the key is still
    // set on any given launch, we know that the last
    // launch crashed.
    //
    // Note that iOS will sometimes kill the app for
    // reasons other than crashing, so there will be
    // some false positives.
    [userDefaults setObject:@(YES) forKey:kNSUserDefaults_DidTerminateKey];
}

- (void)applicationWillTerminate
{
    NSUserDefaults *userDefaults = CurrentAppContext().appUserDefaults;
    [userDefaults removeObjectForKey:kNSUserDefaults_DidTerminateKey];
}

#pragma mark -

- (void)setup {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangeCallLoggingPreference:)
                                                 name:OWSPreferencesCallLoggingDidChangeNotification
                                               object:nil];
}

- (BOOL)hasSelectedThread
{
    return true;
}

#pragma mark - View Convenience Methods

- (void)presentConversationForAddress:(SignalServiceAddress *)address animated:(BOOL)isAnimated
{
    [self presentConversationForAddress:address action:ConversationViewActionNone animated:(BOOL)isAnimated];
}

- (void)presentConversationForAddress:(SignalServiceAddress *)address
                               action:(ConversationViewAction)action
                             animated:(BOOL)isAnimated
{
    __block TSThread *thread = nil;
    
    [self presentConversationForThread:thread action:action animated:(BOOL)isAnimated];
}

- (void)presentConversationForThreadId:(NSString *)threadId animated:(BOOL)isAnimated
{

    __block TSThread *_Nullable thread;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        thread = [TSThread anyFetchWithUniqueId:threadId transaction:transaction];
    }];
    if (thread == nil) {
        return;
    }

    [self presentConversationForThread:thread animated:isAnimated];
}

- (void)presentConversationForThread:(TSThread *)thread animated:(BOOL)isAnimated
{
    [self presentConversationForThread:thread action:ConversationViewActionNone animated:isAnimated];
}

- (void)presentConversationForThread:(TSThread *)thread action:(ConversationViewAction)action animated:(BOOL)isAnimated
{
    [self presentConversationForThread:thread action:action focusMessageId:nil animated:isAnimated];
}

- (void)presentConversationForThread:(TSThread *)thread
                              action:(ConversationViewAction)action
                      focusMessageId:(nullable NSString *)focusMessageId
                            animated:(BOOL)isAnimated
{

    if (!thread) {
        return;
    }
}

- (void)presentConversationAndScrollToFirstUnreadMessageForThreadId:(NSString *)threadId animated:(BOOL)isAnimated
{

    __block TSThread *_Nullable thread;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        thread = [TSThread anyFetchWithUniqueId:threadId transaction:transaction];
    }];
    if (thread == nil) {
        return;
    }
}

- (void)didChangeCallLoggingPreference:(NSNotification *)notification
{
}

#pragma mark - Methods

+ (void)resetAppDataWithUI
{

    DispatchMainThreadSafe(^{
        UIViewController *fromVC = UIApplication.sharedApplication.frontmostViewController;
        [ModalActivityIndicatorViewController
            presentFromViewController:fromVC
                            canCancel:YES
                      backgroundBlock:^(
                          ModalActivityIndicatorViewController *modalActivityIndicator) { [SignalApp resetAppData]; }];
    });
}

+ (void)resetAppData
{

    DispatchSyncMainThreadSafe(^{
        [self.databaseStorage resetAllStorage];
        [Environment.shared.preferences removeAllValues];
        [OWSFileSystem deleteContentsOfDirectory:[OWSFileSystem appSharedDataDirectoryPath]];
        [OWSFileSystem deleteContentsOfDirectory:[OWSFileSystem appDocumentDirectoryPath]];
        [OWSFileSystem deleteContentsOfDirectory:[OWSFileSystem cachesDirectoryPath]];
        [OWSFileSystem deleteContentsOfDirectory:OWSTemporaryDirectory()];
        [OWSFileSystem deleteContentsOfDirectory:NSTemporaryDirectory()];
    });

    [DebugLogger.shared wipeLogs];
    exit(0);
}

- (void)showConversationSplitView
{
    ConversationSplitViewController *splitViewController = [ConversationSplitViewController new];

    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    appDelegate.window.rootViewController = splitViewController;

    self.conversationSplitViewController = splitViewController;
}

- (void)submitOnboardingLogs
{
}

- (void)ensureRootViewController:(NSTimeInterval)launchStartedAt
{

    if (!AppReadiness.isAppReady || self.hasInitialRootViewController) {
        return;
    }
    self.hasInitialRootViewController = YES;

    [UIViewController attemptRotationToDeviceOrientation];
}

- (BOOL)receivedVerificationCode:(NSString *)verificationCode
{
    return YES;
}

- (void)showNewConversationView
{
    [self.conversationSplitViewController showNewConversationView];
}

- (nullable UIView *)snapshotSplitViewControllerAfterScreenUpdates:(BOOL)afterScreenUpdates
{
    return [self.conversationSplitViewController.view snapshotViewAfterScreenUpdates:afterScreenUpdates];
}

- (nullable ConversationSplitViewController *)conversationSplitViewControllerForSwift
{
    return self.conversationSplitViewController;
}

@end

NS_ASSUME_NONNULL_END
