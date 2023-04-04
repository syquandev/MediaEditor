//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "SDSKeyValueStore+ObjC.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface SDSKeyValueStoreObjC ()

@property (nonatomic, readonly) SDSKeyValueStore *keyValueStore;

@end

@implementation SDSKeyValueStoreObjC

- (instancetype)initWithSDSKeyValueStore:(SDSKeyValueStore *)keyValueStore
{
    self = [super init];
    if (!self) {
        return self;
    }

    _keyValueStore = keyValueStore;

    return self;
}

- (nullable id)objectForKey:(NSString *)key ofExpectedType:(Class)klass transaction:(SDSAnyReadTransaction *)transaction
{

    id _Nullable value = [self.keyValueStore getObjectForKey:key transaction:transaction];

    return value;
}

- (void)setObject:(id)object
    ofExpectedType:(Class)klass
            forKey:(NSString *)key
       transaction:(SDSAnyWriteTransaction *)transaction
{
    [self.keyValueStore setObject:object key:key transaction:transaction];
}

@end

NS_ASSUME_NONNULL_END
