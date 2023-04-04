//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@interface AppVersion : NSObject

// These properties are global and available immediately
@property (class, atomic, readonly) NSString *hardwareInfoString;
@property (class, atomic, readonly) NSString *iOSVersionString;

// The properties are updated immediately after launch.
@property (atomic, readonly) NSString *firstAppVersion;
@property (atomic, nullable, readonly) NSString *lastAppVersion;

// The release track.
//
// e.g. 3.4.5
@property (atomic, readonly) NSString *currentAppReleaseVersion;

// Uniquely identifies the build within the release track, in the format specified by Apple.
//
// e.g. 6
//
// See:
//
// * https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleshortversionstring
// * https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleversion
// * https://developer.apple.com/library/archive/technotes/tn2420/_index.html
@property (atomic, readonly) NSString *currentAppBuildVersion;

// Internally, we use a version format with 4 dotted values
// to uniquely identify builds. The first three values are the
// the release version, the fourth value is the last value from
// the build version.
//
// e.g. 3.4.5.6
@property (atomic, readonly) NSString *currentAppVersion4;

// There properties aren't updated until appLaunchDidComplete is called.
@property (atomic, nullable, readonly) NSString *lastCompletedLaunchAppVersion;
@property (atomic, nullable, readonly) NSString *lastCompletedLaunchMainAppVersion;
@property (atomic, nullable, readonly) NSString *lastCompletedLaunchSAEAppVersion;
@property (atomic, nullable, readonly) NSString *lastCompletedLaunchNSEAppVersion;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)shared;

- (void)mainAppLaunchDidComplete;
- (void)saeLaunchDidComplete;
- (void)nseLaunchDidComplete;

- (BOOL)isFirstLaunch;

+ (NSComparisonResult)compareAppVersion:(NSString *)lhs with:(NSString *)rhs;

@end

NS_ASSUME_NONNULL_END
