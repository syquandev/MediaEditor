//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "OWSSignalService.h"
#import "OWSError.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const kisCensorshipCircumventionManuallyActivatedKey
    = @"kTSStorageManager_isCensorshipCircumventionManuallyActivated";
NSString *const kisCensorshipCircumventionManuallyDisabledKey
    = @"kTSStorageManager_isCensorshipCircumventionManuallyDisabled";
NSString *const kManualCensorshipCircumventionCountryCodeKey
    = @"kTSStorageManager_ManualCensorshipCircumventionCountryCode";

NSNotificationName const NSNotificationNameIsCensorshipCircumventionActiveDidChange
    = @"NSNotificationNameIsCensorshipCircumventionActiveDidChange";

@interface OWSSignalService ()

@property (atomic) BOOL hasCensoredPhoneNumber;

@property (atomic) BOOL isCensorshipCircumventionActive;

@end

#pragma mark -

@implementation OWSSignalService

- (SDSKeyValueStore *)keyValueStore
{
    return [[SDSKeyValueStore alloc] initWithCollection:@"kTSStorageManager_OWSSignalService"];
}

#pragma mark -


@synthesize isCensorshipCircumventionActive = _isCensorshipCircumventionActive;

+ (instancetype)shared
{
    static OWSSignalService *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] initDefault]; });
    return shared;
}

- (instancetype)initDefault
{
    self = [super init];
    if (!self) {
        return self;
    }

    [self observeNotifications];

    [self updateHasCensoredPhoneNumber];
    [self updateIsCensorshipCircumventionActive];


    return self;
}

- (void)observeNotifications
{
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateHasCensoredPhoneNumber
{
    [self updateIsCensorshipCircumventionActive];
}

- (BOOL)isCensorshipCircumventionManuallyActivated
{
    __block BOOL result;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        result = [self.keyValueStore getBool:kisCensorshipCircumventionManuallyActivatedKey
                                defaultValue:NO
                                 transaction:transaction];
    } file:__FILE__ function:__FUNCTION__ line:__LINE__];
    return result;
}

- (void)setIsCensorshipCircumventionManuallyActivated:(BOOL)value
{
    
    [self updateIsCensorshipCircumventionActive];
}

- (BOOL)isCensorshipCircumventionManuallyDisabled
{
    __block BOOL result;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        result = [self.keyValueStore getBool:kisCensorshipCircumventionManuallyDisabledKey
                                defaultValue:NO
                                 transaction:transaction];
    } file:__FILE__ function:__FUNCTION__ line:__LINE__];
    return result;
}

- (void)setIsCensorshipCircumventionManuallyDisabled:(BOOL)value
{
   

    [self updateIsCensorshipCircumventionActive];
}


- (void)updateIsCensorshipCircumventionActive
{
    if (self.isCensorshipCircumventionManuallyDisabled) {
        self.isCensorshipCircumventionActive = NO;
    } else if (self.isCensorshipCircumventionManuallyActivated) {
        self.isCensorshipCircumventionActive = YES;
    } else if (self.hasCensoredPhoneNumber) {
        self.isCensorshipCircumventionActive = YES;
    } else {
        self.isCensorshipCircumventionActive = NO;
    }
}

- (void)setIsCensorshipCircumventionActive:(BOOL)isCensorshipCircumventionActive
{
    @synchronized(self)
    {
        if (_isCensorshipCircumventionActive == isCensorshipCircumventionActive) {
            return;
        }

        _isCensorshipCircumventionActive = isCensorshipCircumventionActive;
    }

    [[NSNotificationCenter defaultCenter]
        postNotificationNameAsync:NSNotificationNameIsCensorshipCircumventionActiveDidChange
                           object:nil
                         userInfo:nil];
}

- (BOOL)isCensorshipCircumventionActive
{
    @synchronized(self)
    {
        return _isCensorshipCircumventionActive;
    }
}

- (NSURL *)domainFrontBaseURL
{
    OWSCensorshipConfiguration *censorshipConfiguration = [self buildCensorshipConfiguration];
    return [NSURL URLWithString:@"sssss"];
}

#pragma mark - Events

- (void)registrationStateDidChange:(NSNotification *)notification
{
    [self updateHasCensoredPhoneNumber];
}

- (void)localNumberDidChange:(NSNotification *)notification
{
    [self updateHasCensoredPhoneNumber];
}

#pragma mark - Censorship Circumvention

- (OWSCensorshipConfiguration *)buildCensorshipConfiguration
{
    return nil;
}

- (nullable NSString *)manualCensorshipCircumventionCountryCode
{
    __block NSString *_Nullable result;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        result = [self.keyValueStore getString:kManualCensorshipCircumventionCountryCodeKey transaction:transaction];
    }];
    return result;
}

- (void)setManualCensorshipCircumventionCountryCode:(nullable NSString *)value
{
   
}

@end

NS_ASSUME_NONNULL_END
