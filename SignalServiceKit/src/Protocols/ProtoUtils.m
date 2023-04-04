//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "ProtoUtils.h"
#import "SSKEnvironment.h"
#import "TSThread.h"
#import <SignalCoreKit/Cryptography.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ProtoUtils

+ (OWSAES256Key *)localProfileKey
{
    return nil;
}

#pragma mark -

+ (BOOL)shouldMessageHaveLocalProfileKey:(TSThread *)thread
                             transaction:(SDSAnyReadTransaction *)transaction
{
    // Group threads will return YES if the group is in the whitelist
    // Contact threads will return YES if the contact is in the whitelist.
    return YES;
}

+ (void)addLocalProfileKeyIfNecessary:(TSThread *)thread
                   dataMessageBuilder:(SSKProtoDataMessageBuilder *)dataMessageBuilder
                          transaction:(SDSAnyReadTransaction *)transaction
{
}

+ (void)addLocalProfileKeyToDataMessageBuilder:(SSKProtoDataMessageBuilder *)dataMessageBuilder
{
}

+ (void)addLocalProfileKeyIfNecessary:(TSThread *)thread
                   callMessageBuilder:(SSKProtoCallMessageBuilder *)callMessageBuilder
                          transaction:(SDSAnyReadTransaction *)transaction
{
}

+ (nullable NSString *)parseProtoE164:(nullable NSString *)value name:(NSString *)name
{
    if (value == nil) {
        return nil;
    }
    if (value.length == 0) {
        return nil;
    }
    
    return value;
}

@end

NS_ASSUME_NONNULL_END
