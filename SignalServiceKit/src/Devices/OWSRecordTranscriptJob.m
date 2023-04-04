//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

#import "OWSRecordTranscriptJob.h"
#import "FunctionalUtil.h"
#import "SSKEnvironment.h"
#import "TSAttachmentPointer.h"
#import "TSGroupThread.h"
#import "TSOutgoingMessage.h"
#import "TSThread.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation OWSRecordTranscriptJob

+ (void)processIncomingSentMessageTranscript:(OWSIncomingSentMessageTranscript *)transcript
                                 transaction:(SDSAnyWriteTransaction *)transaction
{
}

+ (void)insertUnknownProtocolVersionErrorForTranscript:(OWSIncomingSentMessageTranscript *)transcript
                                           transaction:(SDSAnyWriteTransaction *)transaction
{
}

#pragma mark -

+ (void)processRecipientUpdateWithTranscript:(OWSIncomingSentMessageTranscript *)transcript
                                 transaction:(SDSAnyWriteTransaction *)transaction
{
}

@end

NS_ASSUME_NONNULL_END
