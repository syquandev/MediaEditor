//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

#import "OWS2FAManager.h"
#import "AppReadiness.h"
#import "SSKEnvironment.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const NSNotificationName_2FAStateDidChange = @"NSNotificationName_2FAStateDidChange";

NSString *const kOWS2FAManager_LastSuccessfulReminderDateKey = @"kOWS2FAManager_LastSuccessfulReminderDateKey";
NSString *const kOWS2FAManager_PinCode = @"kOWS2FAManager_PinCode";
NSString *const kOWS2FAManager_RepetitionInterval = @"kOWS2FAManager_RepetitionInterval";
NSString *const kOWS2FAManager_HasMigratedTruncatedPinKey = @"kOWS2FAManager_HasMigratedTruncatedPinKey";
NSString *const kOWS2FAManager_AreRemindersEnabled = @"kOWS2FAManager_AreRemindersEnabled";

const NSUInteger kHourSecs = 60 * 60;
const NSUInteger kDaySecs = kHourSecs * 24;

const NSUInteger kMin2FAPinLength = 4;
const NSUInteger kMin2FAv2PinLength = 4;
const NSUInteger kMax2FAv1PinLength = 20; // v2 doesn't have a max length
const NSUInteger kLegacyTruncated2FAv1PinLength = 16;

@interface OWS2FAManager ()

@property (nonatomic) OWS2FAMode mode;

@end

#pragma mark -

@implementation OWS2FAManager

#pragma mark -

+ (SDSKeyValueStore *)keyValueStore
{
    NSString *const kOWS2FAManager_Collection = @"kOWS2FAManager_Collection";
    return [[SDSKeyValueStore alloc] initWithCollection:kOWS2FAManager_Collection];
}

#pragma mark -

- (instancetype)init
{
    self = [super init];

    if (!self) {
        return self;
    }

//    AppReadinessRunNowOrWhenMainAppDidBecomeReadyAsync(^{
//        if (self.mode == OWS2FAMode_V1) {
//
//            [self migrateToRegistrationLockV2]
//                .done(^(id value) {  })
//                .catch(^(NSError *error) {
//                });
//        }
//    });

    return self;
}

- (nullable NSString *)pinCode
{
    __block NSString *_Nullable value;
    [self.databaseStorage
        readWithBlock:^(SDSAnyReadTransaction *transaction) { value = [self pinCodeWithTransaction:transaction]; }];
    return value;
}

- (nullable NSString *)pinCodeWithTransaction:(SDSAnyReadTransaction *)transaction
{
    return [OWS2FAManager.keyValueStore getString:kOWS2FAManager_PinCode transaction:transaction];
}

- (void)setPinCode:(nullable NSString *)pin transaction:(SDSAnyWriteTransaction *)transaction
{
    if (pin.length == 0) {
        [OWS2FAManager.keyValueStore removeValueForKey:kOWS2FAManager_PinCode transaction:transaction];
        return;
    }

    [OWS2FAManager.keyValueStore setString:pin key:kOWS2FAManager_PinCode transaction:transaction];
}

- (OWS2FAMode)mode
{
    return OWS2FAMode_Disabled;
}

- (BOOL)is2FAEnabled
{
    return self.mode != OWS2FAMode_Disabled;
}

- (void)markDisabledWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [OWS2FAManager.keyValueStore removeValueForKey:kOWS2FAManager_PinCode transaction:transaction];
    [OWS2FAManager.keyValueStore removeValueForKey:OWS2FAManager.isRegistrationLockV2EnabledKey transaction:transaction];

    [transaction addSyncCompletion:^{
        [[NSNotificationCenter defaultCenter] postNotificationNameAsync:NSNotificationName_2FAStateDidChange
                                                                 object:nil
                                                               userInfo:nil];
    }];
}

- (void)markEnabledWithPin:(NSString *)pin transaction:(SDSAnyWriteTransaction *)transaction
{
    [self setPinCode:pin transaction:transaction];

    // Since we just created this pin, we know it doesn't need migration. Mark it as such.
    [self markLegacyPinAsMigratedWithTransaction:transaction];

    // Reset the reminder repetition interval for the new pin.
    [self setDefaultRepetitionIntervalWithTransaction:transaction];

    // Schedule next reminder relative to now
    [self setLastCompletedReminderDate:[NSDate new] transaction:transaction];

    [transaction addSyncCompletion:^{
        [[NSNotificationCenter defaultCenter] postNotificationNameAsync:NSNotificationName_2FAStateDidChange
                                                                 object:nil
                                                               userInfo:nil];

    }];
}

- (void)requestEnable2FAWithPin:(NSString *)pin
                           mode:(OWS2FAMode)mode
                rotateMasterKey:(BOOL)rotateMasterKey
                        success:(nullable OWS2FASuccess)success
                        failure:(nullable OWS2FAFailure)failure
{

    switch (mode) {
        case OWS2FAMode_V2: {
            break;
        }
        case OWS2FAMode_V1:
            [self enable2FAV1WithPin:pin success:success failure:failure];
            break;
        case OWS2FAMode_Disabled:
            break;
    }
}

- (void)disable2FAWithSuccess:(nullable OWS2FASuccess)success failure:(nullable OWS2FAFailure)failure
{
    switch (self.mode) {
        case OWS2FAMode_V2:
        {
            break;
        }
        case OWS2FAMode_V1:
            [self disable2FAV1WithSuccess:success failure:failure];
            break;
        case OWS2FAMode_Disabled:
            break;
    }
}


#pragma mark - Reminders

- (nullable NSDate *)lastCompletedReminderDateWithTransaction:(SDSAnyReadTransaction *)transaction
{
    return [OWS2FAManager.keyValueStore getDate:kOWS2FAManager_LastSuccessfulReminderDateKey transaction:transaction];
}

- (void)setLastCompletedReminderDate:(nullable NSDate *)date transaction:(SDSAnyWriteTransaction *)transaction
{
    [OWS2FAManager.keyValueStore setDate:date key:kOWS2FAManager_LastSuccessfulReminderDateKey transaction:transaction];
}

- (BOOL)isDueForV2ReminderWithTransaction:(SDSAnyReadTransaction *)transaction
{
    if ([self pinCodeWithTransaction:transaction].length == 0) {
        return YES;
    }

    if (![self areRemindersEnabledTransaction:transaction]) {
        return NO;
    }

    NSDate *nextReminderDate = [self nextReminderDateWithTransaction:transaction];

    return nextReminderDate.timeIntervalSinceNow < 0;
}

- (BOOL)needsLegacyPinMigration
{
    __block BOOL hasMigratedTruncatedPin = NO;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        hasMigratedTruncatedPin = [OWS2FAManager.keyValueStore getBool:kOWS2FAManager_HasMigratedTruncatedPinKey
                                                          defaultValue:NO
                                                           transaction:transaction];
    }];

    if (hasMigratedTruncatedPin) {
        return NO;
    }

    // Older versions of the app truncated newly created pins to 16 characters. We no longer do that.
    // If we detect that the user's pin is the truncated length and it was created before we stopped
    // truncating pins, we'll need to ensure we migrate to the user's entire pin next time we prompt
    // them for it.
    if (self.mode == OWS2FAMode_V1 && self.pinCode.length >= kLegacyTruncated2FAv1PinLength) {
        return YES;
    }

    // We don't need to migrate this pin, either because it's v2 or short enough that
    // we never truncated it. Mark it as complete so we don't need to check again.


    return NO;
}

- (void)markLegacyPinAsMigratedWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [OWS2FAManager.keyValueStore setBool:YES key:kOWS2FAManager_HasMigratedTruncatedPinKey transaction:transaction];
}

- (void)verifyPin:(NSString *)pin result:(void (^_Nonnull)(BOOL))result
{
    NSString *pinToMatch = self.pinCode;

    switch (self.mode) {
    case OWS2FAMode_V2:
        break;
    case OWS2FAMode_V1:
        // Convert the pin to arabic numerals, we never want to
        // operate with pins in other numbering systems.
        result([pinToMatch.ensureArabicNumerals isEqualToString:pin.ensureArabicNumerals]);
        break;
    case OWS2FAMode_Disabled:
        result(NO);
        break;
    }
}

- (NSDate *)nextReminderDate
{
    __block NSDate *_Nullable value;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        value = [self nextReminderDateWithTransaction:transaction];
    }];
    return value;
}

- (NSDate *)nextReminderDateWithTransaction:(SDSAnyReadTransaction *)transaction
{
    NSDate *lastCompletedReminderDate =
        [self lastCompletedReminderDateWithTransaction:transaction] ?: [NSDate distantPast];
    NSTimeInterval repetitionInterval = [self repetitionIntervalWithTransaction:transaction];

    return [lastCompletedReminderDate dateByAddingTimeInterval:repetitionInterval];
}

- (NSArray<NSNumber *> *)allRepetitionIntervals
{
    // Keep sorted monotonically increasing.
    return @[
        @(12 * kHourSecs),
        @(1 * kDaySecs),
        @(3 * kDaySecs),
        @(7 * kDaySecs),
        @(14 * kDaySecs),
    ];
}

- (double)defaultRepetitionInterval
{
    return self.allRepetitionIntervals.firstObject.doubleValue;
}

- (NSTimeInterval)repetitionInterval
{
    __block NSTimeInterval value;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        value = [self repetitionIntervalWithTransaction:transaction];
    }];
    return value;
}

- (NSTimeInterval)repetitionIntervalWithTransaction:(SDSAnyReadTransaction *)transaction
{
    return [OWS2FAManager.keyValueStore getDouble:kOWS2FAManager_RepetitionInterval
                                     defaultValue:self.defaultRepetitionInterval
                                      transaction:transaction];
}

- (void)reminderCompletedWithIncorrectAttempts:(BOOL)incorrectAttempts
{

}

- (NSTimeInterval)adjustRepetitionInterval:(NSTimeInterval)oldInterval withIncorrectAttempts:(BOOL)incorrectAttempts
{
    NSArray<NSNumber *> *allIntervals = self.allRepetitionIntervals;

    NSUInteger oldIndex =
        [allIntervals indexOfObjectPassingTest:^BOOL(NSNumber *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            return oldInterval <= (NSTimeInterval)obj.doubleValue;
        }];

    NSUInteger newIndex;
    if (!incorrectAttempts) {
        newIndex = oldIndex + 1;
    } else {
        // prevent overflow
        newIndex = oldIndex <= 0 ? 0 : oldIndex - 1;
    }

    // clamp to be valid
    newIndex = MAX(0, MIN(allIntervals.count - 1, newIndex));

    NSTimeInterval newInterval = allIntervals[newIndex].doubleValue;
    return newInterval;
}

- (void)setDefaultRepetitionIntervalWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [OWS2FAManager.keyValueStore setDouble:self.defaultRepetitionInterval
                                       key:kOWS2FAManager_RepetitionInterval
                               transaction:transaction];
}

- (BOOL)areRemindersEnabled
{
    __block BOOL areRemindersEnabled;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        areRemindersEnabled = [self areRemindersEnabledTransaction:transaction];
    }];
    return areRemindersEnabled;
}

- (BOOL)areRemindersEnabledTransaction:(SDSAnyReadTransaction *)transaction
{
    return [OWS2FAManager.keyValueStore getBool:kOWS2FAManager_AreRemindersEnabled
                                   defaultValue:YES
                                    transaction:transaction];
}

- (void)setAreRemindersEnabled:(BOOL)areRemindersEnabled transaction:(SDSAnyWriteTransaction *)transaction
{
    return [OWS2FAManager.keyValueStore setBool:areRemindersEnabled
                                            key:kOWS2FAManager_AreRemindersEnabled
                                    transaction:transaction];
}

@end

NS_ASSUME_NONNULL_END
