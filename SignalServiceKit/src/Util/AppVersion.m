//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

#import "AppVersion.h"
#import "NSUserDefaults+OWS.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const kNSUserDefaults_FirstAppVersion = @"kNSUserDefaults_FirstAppVersion";
NSString *const kNSUserDefaults_LastAppVersion = @"kNSUserDefaults_LastVersion";
NSString *const kNSUserDefaults_LastCompletedLaunchAppVersion = @"kNSUserDefaults_LastCompletedLaunchAppVersion";
NSString *const kNSUserDefaults_LastCompletedLaunchAppVersion_MainApp
    = @"kNSUserDefaults_LastCompletedLaunchAppVersion_MainApp";
NSString *const kNSUserDefaults_LastCompletedLaunchAppVersion_SAE
    = @"kNSUserDefaults_LastCompletedLaunchAppVersion_SAE";
NSString *const kNSUserDefaults_LastCompletedLaunchAppVersion_NSE
    = @"kNSUserDefaults_LastCompletedLaunchAppVersion_NSE";

@interface AppVersion ()

@property (atomic) NSString *firstAppVersion;
@property (atomic, nullable) NSString *lastAppVersion;

@property (atomic, nullable) NSString *lastCompletedLaunchAppVersion;
@property (atomic, nullable) NSString *lastCompletedLaunchMainAppVersion;
@property (atomic, nullable) NSString *lastCompletedLaunchSAEAppVersion;
@property (atomic, nullable) NSString *lastCompletedLaunchNSEAppVersion;

@end

#pragma mark -

@implementation AppVersion

+ (instancetype)shared
{
    static AppVersion *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [AppVersion new];
        [instance configure];
    });
    return instance;
}

+ (NSString *)hardwareInfoString
{
    NSString *marketingString = UIDevice.currentDevice.model;
    NSString *machineString = [NSString stringFromSysctlKey:@"hw.machine"];
    NSString *modelString = [NSString stringFromSysctlKey:@"hw.model"];
    return [NSString stringWithFormat:@"%@ (%@; %@)", marketingString, machineString, modelString];
}

+ (NSString *)iOSVersionString
{
    NSString *majorMinor = UIDevice.currentDevice.systemVersion;
    NSString *buildNumber = [NSString stringFromSysctlKey:@"kern.osversion"];
    return [NSString stringWithFormat:@"%@ (%@)", majorMinor, buildNumber];
}

- (void)configure {

    if (CurrentAppContext().isRunningTests) {
        _currentAppReleaseVersion = @"1.2.3";
        _currentAppBuildVersion = @"4";
        _currentAppVersion4 = @"1.2.3.4";
    } else {
        _currentAppReleaseVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        _currentAppBuildVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
        _currentAppVersion4 = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"OWSBundleVersion4"];
    }

    // The version of the app when it was first launched.
    // nil if the app has never been launched before.
    self.firstAppVersion = [[NSUserDefaults appUserDefaults] objectForKey:kNSUserDefaults_FirstAppVersion];
    // The version of the app the last time it was launched.
    // nil if the app has never been launched before.
    self.lastAppVersion = [[NSUserDefaults appUserDefaults] objectForKey:kNSUserDefaults_LastAppVersion];
    self.lastCompletedLaunchAppVersion =
        [[NSUserDefaults appUserDefaults] objectForKey:kNSUserDefaults_LastCompletedLaunchAppVersion];
    self.lastCompletedLaunchMainAppVersion =
        [[NSUserDefaults appUserDefaults] objectForKey:kNSUserDefaults_LastCompletedLaunchAppVersion_MainApp];
    self.lastCompletedLaunchSAEAppVersion =
        [[NSUserDefaults appUserDefaults] objectForKey:kNSUserDefaults_LastCompletedLaunchAppVersion_SAE];
    self.lastCompletedLaunchNSEAppVersion =
        [[NSUserDefaults appUserDefaults] objectForKey:kNSUserDefaults_LastCompletedLaunchAppVersion_NSE];

    // Ensure the value for the "first launched version".
    if (!self.firstAppVersion) {
        self.firstAppVersion = self.currentAppReleaseVersion;
        [[NSUserDefaults appUserDefaults] setObject:self.currentAppReleaseVersion
                                             forKey:kNSUserDefaults_FirstAppVersion];
    }
    
    // Update the value for the "most recently launched version".
    [[NSUserDefaults appUserDefaults] setObject:self.currentAppReleaseVersion forKey:kNSUserDefaults_LastAppVersion];
    [[NSUserDefaults appUserDefaults] synchronize];

    [self startupLogging];
}

- (void)startupLogging
{
    NSString *localeIdentifier = [NSLocale.currentLocale objectForKey:NSLocaleIdentifier];
    if (localeIdentifier.length > 0) {
    }
    NSString *countryCode = [NSLocale.currentLocale objectForKey:NSLocaleCountryCode];
    if (countryCode.length > 0) {
    }
    NSString *languageCode = [NSLocale.currentLocale objectForKey:NSLocaleLanguageCode];
    if (languageCode.length > 0) {
    }


    if (SSKDebugFlags.internalLogging) {
        NSString *_Nullable bundleName = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleName"];
        if (bundleName.length > 0) {
        }
        NSString *_Nullable bundleDisplayName = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        if (bundleDisplayName.length > 0) {
        }
    }
}

- (void)appLaunchDidComplete
{

    self.lastCompletedLaunchAppVersion = self.currentAppReleaseVersion;

    // Update the value for the "most recently launch-completed version".
    [[NSUserDefaults appUserDefaults] setObject:self.currentAppReleaseVersion
                                         forKey:kNSUserDefaults_LastCompletedLaunchAppVersion];
    [[NSUserDefaults appUserDefaults] synchronize];
}

- (void)mainAppLaunchDidComplete
{

    self.lastCompletedLaunchMainAppVersion = self.currentAppReleaseVersion;
    [[NSUserDefaults appUserDefaults] setObject:self.currentAppReleaseVersion
                                         forKey:kNSUserDefaults_LastCompletedLaunchAppVersion_MainApp];

    [self appLaunchDidComplete];
}

- (void)saeLaunchDidComplete
{

    self.lastCompletedLaunchSAEAppVersion = self.currentAppReleaseVersion;
    [[NSUserDefaults appUserDefaults] setObject:self.currentAppReleaseVersion
                                         forKey:kNSUserDefaults_LastCompletedLaunchAppVersion_SAE];

    [self appLaunchDidComplete];
}

- (void)nseLaunchDidComplete
{

    self.lastCompletedLaunchNSEAppVersion = self.currentAppReleaseVersion;
    [[NSUserDefaults appUserDefaults] setObject:self.currentAppReleaseVersion
                                         forKey:kNSUserDefaults_LastCompletedLaunchAppVersion_NSE];

    [self appLaunchDidComplete];
}

- (BOOL)isFirstLaunch
{
    return self.firstAppVersion != nil;
}

+ (NSComparisonResult)compareAppVersion:(NSString *)lhs with:(NSString *)rhs
{
    // It might be nice to have a first-class version struct that's comparable, but it's not important right now.
    NSArray<NSString *> *lhsComponents = [lhs componentsSeparatedByString:@"."];
    NSArray<NSString *> *rhsComponents = [rhs componentsSeparatedByString:@"."];

    NSUInteger largestIdx = MAX(lhsComponents.count, rhsComponents.count);
    for (NSInteger idx = 0; idx < largestIdx; idx++) {
        // If we run off the end of an array, we'll assume zero for the component segment
        NSString *lhsComponentString = (idx < lhsComponents.count) ? lhsComponents[idx] : nil;
        NSString *rhsComponentString = (idx < rhsComponents.count) ? rhsComponents[idx] : nil;
        NSInteger lhsComponent = [lhsComponentString integerValue];
        NSInteger rhsComponent = [rhsComponentString integerValue];

        if (lhsComponent != rhsComponent) {
            return (lhsComponent < rhsComponent) ? NSOrderedAscending : NSOrderedDescending;
        }
    }

    // If we get here, the versions are effectively equal
    return NSOrderedSame;
}

@end

NS_ASSUME_NONNULL_END
