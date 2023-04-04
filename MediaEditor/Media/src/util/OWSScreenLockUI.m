//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "OWSScreenLockUI.h"
#import "OWSWindowManager.h"
#import <MediaEditor-Swift.h>
#import "ScreenLockViewController.h"
#import "UIView+SignalUI.h"

NS_ASSUME_NONNULL_BEGIN

@interface OWSScreenLockUI () <ScreenLockViewDelegate>

@property (nonatomic) UIWindow *screenBlockingWindow;
@property (nonatomic) ScreenLockViewController *screenBlockingViewController;

// Unlike UIApplication.applicationState, this state reflects the
// notifications, i.e. "did become active", "will resign active",
// "will enter foreground", "did enter background".
//
// We want to update our state to reflect these transitions and have
// the "update" logic be consistent with "last reported" state. i.e.
// when you're responding to "will resign active", we need to behave
// as though we're already inactive.
//
// Secondly, we need to show the screen protection _before_ we become
// inactive in order for it to be reflected in the app switcher.
@property (nonatomic) BOOL appIsInactiveOrBackground;
@property (nonatomic) BOOL appIsInBackground;

@property (nonatomic) BOOL isShowingScreenLockUI;

@property (nonatomic) BOOL didLastUnlockAttemptFail;

// We want to remain in "screen lock" mode while "local auth"
// UI is dismissing. So we lazily clear isShowingScreenLockUI
// using this property.
@property (nonatomic) BOOL shouldClearAuthUIWhenActive;

// Indicates whether or not the user is currently locked out of
// the app.  Should only be set if OWSScreenLock.isScreenLockEnabled.
//
// * The user is locked out by default on app launch.
// * The user is also locked out if they spend more than
//   "timeout" seconds outside the app.  When the user leaves
//   the app, a "countdown" begins.
@property (nonatomic) BOOL isScreenLockLocked;

// The "countdown" until screen lock takes effect.
@property (nonatomic, nullable) NSDate *screenLockCountdownDate;

@end

#pragma mark -

@implementation OWSScreenLockUI

+ (instancetype)shared
{
    static OWSScreenLockUI *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initDefault];
    });
    return instance;
}

- (instancetype)initDefault
{
    self = [super init];

    if (!self) {
        return self;
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)observeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:OWSApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:OWSApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:OWSApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clockDidChange:)
                                                 name:NSSystemClockDidChangeNotification
                                               object:nil];
}

- (void)setupWithRootWindow:(UIWindow *)rootWindow
{
    [self createScreenBlockingWindowWithRootWindow:rootWindow];
}

- (void)startObserving
{
    _appIsInactiveOrBackground = [UIApplication sharedApplication].applicationState != UIApplicationStateActive;

    [self observeNotifications];

    // Hide the screen blocking window until "app is ready" to
    // avoid blocking the loading view.
    [self updateScreenBlockingWindow:ScreenLockUIStateNone animated:NO];
}

#pragma mark - Methods

- (void)tryToActivateScreenLockBasedOnCountdown
{

    if (self.isScreenLockLocked) {
        return;
    }
    if (!self.screenLockCountdownDate) {
        return;
    }
    NSTimeInterval countdownInterval = fabs([self.screenLockCountdownDate timeIntervalSinceNow]);
}

// Setter for property indicating that the app is either
// inactive or in the background, e.g. not "foreground and active."
- (void)setAppIsInactiveOrBackground:(BOOL)appIsInactiveOrBackground
{

    _appIsInactiveOrBackground = appIsInactiveOrBackground;

    if (appIsInactiveOrBackground) {
        if (!self.isShowingScreenLockUI) {
            [self startScreenLockCountdownIfNecessary];
        }
    } else {
        [self tryToActivateScreenLockBasedOnCountdown];
        self.screenLockCountdownDate = nil;
    }

    [self ensureUI];
}

// Setter for property indicating that the app is in the background.
// If true, by definition the app is not active.
- (void)setAppIsInBackground:(BOOL)appIsInBackground
{

    _appIsInBackground = appIsInBackground;

    if (self.appIsInBackground) {
        [self startScreenLockCountdownIfNecessary];
    } else {
        [self tryToActivateScreenLockBasedOnCountdown];
    }

    [self ensureUI];
}

- (void)startScreenLockCountdownIfNecessary
{

    if (!self.screenLockCountdownDate) {
        self.screenLockCountdownDate = [NSDate new];
    }

    self.didLastUnlockAttemptFail = NO;
}

// Ensure that:
//
// * The blocking window has the correct state.
// * That we show the "iOS auth UI to unlock" if necessary.
- (void)ensureUI
{
    ScreenLockUIState desiredUIState = self.desiredUIState;

    [self updateScreenBlockingWindow:desiredUIState animated:YES];

    // Show the "iOS auth UI to unlock" if necessary.
    if (desiredUIState == ScreenLockUIStateScreenLock && !self.didLastUnlockAttemptFail) {
        [self tryToPresentAuthUIToUnlockScreenLock];
    }
}

- (void)tryToPresentAuthUIToUnlockScreenLock
{

    if (self.isShowingScreenLockUI) {
        // We're already showing the auth UI; abort.
        return;
    }
    if (self.appIsInactiveOrBackground) {
        // Never show the auth UI unless active.
        return;
    }

    self.isShowingScreenLockUI = YES;

    [self ensureUI];
}

// Determines what the state of the app should be.
- (ScreenLockUIState)desiredUIState
{
    if (self.isScreenLockLocked) {
        if (self.appIsInactiveOrBackground) {
            return ScreenLockUIStateScreenProtection;
        } else {
            return ScreenLockUIStateScreenLock;
        }
    }

    if (!self.appIsInactiveOrBackground) {
        return ScreenLockUIStateNone;
    }
    return ScreenLockUIStateNone;
}

- (void)showScreenLockFailureAlertWithMessage:(NSString *)message
{
    [OWSActionSheets showActionSheetWithTitle:NSLocalizedString(@"SCREEN_LOCK_UNLOCK_FAILED",
                                                  @"Title for alert indicating that screen lock could not be unlocked.")
                                      message:message
                                  buttonTitle:nil
                                 buttonAction:^(ActionSheetAction *action) {
                                     // After the alert, update the UI.
                                     [self ensureUI];
                                 }
                           fromViewController:self.screenBlockingWindow.rootViewController];
}

// 'Screen Blocking' window obscures the app screen:
//
// * In the app switcher.
// * During 'Screen Lock' unlock process.
- (void)createScreenBlockingWindowWithRootWindow:(UIWindow *)rootWindow
{
    UIWindow *window = [[OWSWindow alloc] initWithFrame:rootWindow.bounds];
    window.hidden = NO;
    window.windowLevel = UIWindowLevel_Background;
    window.opaque = YES;
    window.backgroundColor = Theme.launchScreenBackgroundColor;

    ScreenLockViewController *viewController = [ScreenLockViewController new];
    viewController.delegate = self;
    window.rootViewController = viewController;

    self.screenBlockingWindow = window;
    self.screenBlockingViewController = viewController;
}

// The "screen blocking" window has three possible states:
//
// * "Just a logo".  Used when app is launching and in app switcher.  Must match the "Launch Screen"
//    storyboard pixel-for-pixel.
// * "Screen Lock, local auth UI presented". Move the Signal logo so that it is visible.
// * "Screen Lock, local auth UI not presented". Move the Signal logo so that it is visible,
//    show "unlock" button.
- (void)updateScreenBlockingWindow:(ScreenLockUIState)desiredUIState animated:(BOOL)animated
{

    BOOL shouldShowBlockWindow = desiredUIState != ScreenLockUIStateNone;

//    [OWSWindowManager.shared setIsScreenBlockActive:shouldShowBlockWindow];

    [self.screenBlockingViewController updateUIWithState:desiredUIState
                                             isLogoAtTop:self.isShowingScreenLockUI
                                                animated:animated];
}

#pragma mark - Events

- (void)screenLockDidChange:(NSNotification *)notification
{
    [self ensureUI];
}

- (void)clearAuthUIWhenActive
{
    // For continuity, continue to present blocking screen in "screen lock" mode while
    // dismissing the "local auth UI".
    if (self.appIsInactiveOrBackground) {
        self.shouldClearAuthUIWhenActive = YES;
    } else {
        self.isShowingScreenLockUI = NO;
        [self ensureUI];
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    if (self.shouldClearAuthUIWhenActive) {
        self.shouldClearAuthUIWhenActive = NO;
        self.isShowingScreenLockUI = NO;
    }

    self.appIsInactiveOrBackground = NO;
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    self.appIsInactiveOrBackground = YES;
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    self.appIsInBackground = NO;
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    self.appIsInBackground = YES;
}

// Whenever the device date/time is edited by the user,
// trigger screen lock immediately if enabled.
- (void)clockDidChange:(NSNotification *)notification
{
    [self ensureUI];
}

#pragma mark - ScreenLockViewDelegate

- (void)unlockButtonWasTapped
{

    if (self.appIsInactiveOrBackground) {
        // This button can be pressed while the app is inactive
        // for a brief window while the iOS auth UI is dismissing.
        return;
    }

    self.didLastUnlockAttemptFail = NO;

    [self ensureUI];
}

@end

NS_ASSUME_NONNULL_END
