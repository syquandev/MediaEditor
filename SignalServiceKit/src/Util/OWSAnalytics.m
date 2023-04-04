//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "OWSAnalytics.h"
#import <CocoaLumberjack/CocoaLumberjack.h>

NS_ASSUME_NONNULL_BEGIN

@implementation OWSAnalytics

+ (instancetype)shared
{
    static OWSAnalytics *instance = nil;
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

- (long)orderOfMagnitudeOf:(long)value
{
    return [OWSAnalytics orderOfMagnitudeOf:value];
}

+ (long)orderOfMagnitudeOf:(long)value
{
    if (value <= 0) {
        return 0;
    }
    return (long)round(pow(10, floor(log10(value))));
}

+ (void)logEvent:(NSString *)eventName
        severity:(OWSAnalyticsSeverity)severity
      parameters:(nullable NSDictionary *)parameters
        location:(const char *)location
            line:(int)line
{
    [[self shared] logEvent:eventName severity:severity parameters:parameters location:location line:line];
}

- (void)logEvent:(NSString *)eventName
        severity:(OWSAnalyticsSeverity)severity
      parameters:(nullable NSDictionary *)parameters
        location:(const char *)location
            line:(int)line
{
    DDLogFlag logFlag;
    switch (severity) {
        case OWSAnalyticsSeverityInfo:
            logFlag = DDLogFlagInfo;
            break;
        case OWSAnalyticsSeverityError:
            logFlag = DDLogFlagError;
            break;
        case OWSAnalyticsSeverityCritical:
            logFlag = DDLogFlagError;
            break;
        default:
            logFlag = DDLogFlagDebug;
            break;
    }

    // Log the event.
    NSString *logString = [NSString stringWithFormat:@"%s:%d %@", location, line, eventName];
    if (![self shouldReportAsync:severity]) {
    }
}

- (BOOL)shouldReportAsync:(OWSAnalyticsSeverity)severity
{
    return severity != OWSAnalyticsSeverityCritical;
}

#pragma mark - Logging

+ (void)appLaunchDidBegin
{
    [self.shared appLaunchDidBegin];
}

- (void)appLaunchDidBegin
{
    OWSProdInfo([OWSAnalyticsEvents appLaunch]);
}

@end

NS_ASSUME_NONNULL_END
