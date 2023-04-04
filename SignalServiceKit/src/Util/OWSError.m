//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "OWSError.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const OWSSignalServiceKitErrorDomain = @"OWSSignalServiceKitErrorDomain";

NSError *OWSErrorMakeAssertionError(NSString *descriptionFormat, ...)
{
    va_list args;
    va_start(args, descriptionFormat);
    va_end(args);
    return
        [OWSError withError:OWSErrorCodeAssertionFailure
                description:OWSLocalizedString(@"ERROR_DESCRIPTION_UNKNOWN_ERROR", @"Worst case generic error message")
                isRetryable:NO];
}

NSError *OWSErrorMakeGenericError(NSString *descriptionFormat, ...)
{
    va_list args;
    va_start(args, descriptionFormat);
    va_end(args);
    return
        [OWSError withError:OWSErrorCodeGenericFailure
                description:OWSLocalizedString(@"ERROR_DESCRIPTION_UNKNOWN_ERROR", @"Worst case generic error message")
                isRetryable:NO];
}

NS_ASSUME_NONNULL_END
