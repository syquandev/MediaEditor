//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "OWSLinkedDeviceReadReceipt.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

NSUInteger const OWSLinkedDeviceReadReceiptSchemaVersion = 1;

@interface OWSLinkedDeviceReadReceipt ()

@property (nonatomic, nullable, readonly) NSString *senderPhoneNumber;
@property (nonatomic, nullable, readonly) NSString *senderUUID;
@property (nonatomic, readonly) NSUInteger linkedDeviceReadReceiptSchemaVersion;

@end

@implementation OWSLinkedDeviceReadReceipt

- (instancetype)initWithSenderAddress:(SignalServiceAddress *)address
                      messageUniqueId:(nullable NSString *)messageUniqueId
                   messageIdTimestamp:(uint64_t)messageIdTimestamp
                        readTimestamp:(uint64_t)readTimestamp
{

    self = [super init];
    if (!self) {
        return self;
    }

    _senderPhoneNumber = address.phoneNumber;
    _senderUUID = address.uuidString;
    _messageUniqueId = messageUniqueId;
    _messageIdTimestamp = messageIdTimestamp;
    _readTimestamp = readTimestamp;
    _linkedDeviceReadReceiptSchemaVersion = OWSLinkedDeviceReadReceiptSchemaVersion;

    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) {
        return self;
    }

    // renamed timestamp -> messageIdTimestamp
    if (!_messageIdTimestamp) {
        NSNumber *_Nullable legacyTimestamp = (NSNumber *)[coder decodeObjectForKey:@"timestamp"];
        _messageIdTimestamp = legacyTimestamp.unsignedLongLongValue;
    }

    // For legacy objects, before we were tracking read time, use the original messages "sent" timestamp
    // as the local read time. This will always be at least a little bit earlier than the message was
    // actually read, which isn't ideal, but safer than persisting a disappearing message too long, especially
    // since we know they read it on their linked desktop.
    if (_readTimestamp == 0) {
        _readTimestamp = _messageIdTimestamp;
    }

    if (_linkedDeviceReadReceiptSchemaVersion < 1) {
        _senderPhoneNumber = [coder decodeObjectForKey:@"senderId"];
    }

    _linkedDeviceReadReceiptSchemaVersion = OWSLinkedDeviceReadReceiptSchemaVersion;

    return self;
}

- (SignalServiceAddress *)senderAddress
{
    return [[SignalServiceAddress alloc] initWithUuidString:self.senderUUID phoneNumber:self.senderPhoneNumber];
}

@end

NS_ASSUME_NONNULL_END
