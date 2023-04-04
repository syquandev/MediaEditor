//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MessageBodyRanges;

// This header exposes private properties for SDS serialization.

@interface TSThread (SDS)

@property (nonatomic, copy, nullable, readonly) NSString *messageDraft;
@property (nonatomic, readonly, nullable) MessageBodyRanges *messageDraftBodyRanges;

@end

#pragma mark -

@interface TSMessage (SDS)

// This property is only intended to be used by GRDB queries.
@property (nonatomic, readonly) BOOL storedShouldStartExpireTimer;

@end

#pragma mark -

@interface TSOutgoingMessage (SDS)

@property (nonatomic, readonly) TSOutgoingMessageState legacyMessageState;
@property (nonatomic, readonly) BOOL legacyWasDelivered;
@property (nonatomic, readonly) BOOL hasLegacyMessageState;
@property (atomic, nullable, readonly)
    NSDictionary<SignalServiceAddress *, TSOutgoingMessageRecipientState *> *recipientAddressStates;
@property (nonatomic, readonly) TSOutgoingMessageState storedMessageState;

@end

#pragma mark -

@interface TSAttachmentPointer (SDS)

@property (nonatomic, nullable, readonly) NSString *lazyRestoreFragmentId;

@end

#pragma mark -

@interface TSAttachmentStream (SDS)

@property (nullable, nonatomic, readonly) NSString *localRelativeFilePath;

@property (nullable, nonatomic, readonly) NSNumber *cachedImageWidth;
@property (nullable, nonatomic, readonly) NSNumber *cachedImageHeight;

@property (nullable, nonatomic, readonly) NSNumber *cachedAudioDurationSeconds;

@property (atomic, nullable, readonly) NSNumber *isValidImageCached;
@property (atomic, nullable, readonly) NSNumber *isValidVideoCached;
@property (atomic, nullable, readonly) NSNumber *isAnimatedCached;

@end

#pragma mark -

@interface TSContactThread (SDS)

@property (nonatomic, nullable, readonly) NSString *contactPhoneNumber;
@property (nonatomic, nullable, readonly) NSString *contactUUID;

@end


