//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "NSData+keyVersionByte.h"
#import "AxolotlExceptions.h"
#import <SignalCoreKit/SCKExceptionWrapper.h>

NS_ASSUME_NONNULL_BEGIN

@implementation NSData (keyVersionByte)

const Byte DJB_TYPE = 0x05;

- (instancetype)prependKeyType {
    if (self.length == 32) {
        NSMutableData *data = [NSMutableData dataWithBytes:&DJB_TYPE length:1];
        [data appendData:self.copy];
        return data;
    }
    return self;
}

- (nullable instancetype)removeKeyTypeAndReturnError:(NSError **)outError
{
    @try {
        return self.throws_removeKeyType;
    } @catch (NSException *exception) {
        *outError = SCKExceptionWrapperErrorMake(exception);
        return nil;
    }
}

- (instancetype)throws_removeKeyType
{
    if (self.length == 33) {
        if ([[self subdataWithRange:NSMakeRange(0, 1)] isEqualToData:[NSData dataWithBytes:&DJB_TYPE length:1]]) {
            return [self subdataWithRange:NSMakeRange(1, 32)];
        } else{
            @throw [NSException exceptionWithName:InvalidKeyException reason:@"Key type is incorrect" userInfo:@{}];
        }
    } else {
        return self;
    }
}

@end

NS_ASSUME_NONNULL_END
