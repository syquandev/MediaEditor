//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "FunctionalUtil.h"

NS_ASSUME_NONNULL_BEGIN

@interface FUBadArgument : NSException

+ (FUBadArgument *) new:(NSString *)reason;
+ (void)raise:(NSString *)message;

@end

@implementation FUBadArgument

+ (FUBadArgument *) new:(NSString *)reason {
    return [[FUBadArgument alloc] initWithName:@"Invalid Argument" reason:reason userInfo:nil];
}
+ (void)raise:(NSString *)message {
    [FUBadArgument raise:@"Invalid Argument" format:@"%@", message];
}

@end


@implementation NSArray (FunctionalUtil)

- (nullable id)firstSatisfying:(BOOL (^)(id))predicate
{
    for (id e in self) {
        if (predicate(e)) {
            return e;
        }
    }
    return nil;
}

- (BOOL)anySatisfy:(BOOL (^)(id item))predicate
{
    return [self firstSatisfying:predicate] != nil;
}

- (BOOL)allSatisfy:(BOOL (^)(id item))predicate
{
    for (id e in self) {
        if (!predicate(e)) {
            return false;
        }
    }
    return true;
}

- (NSArray *)map:(id (^)(id item))projection {

    NSMutableArray *r = [NSMutableArray arrayWithCapacity:self.count];
    for (id e in self) {
        [r addObject:projection(e)];
    }
    return r;
}

- (NSArray *)filter:(BOOL (^)(id item))predicate
{

    NSMutableArray *r = [NSMutableArray array];
    for (id e in self) {
        if (predicate(e)) {
            [r addObject:e];
        }
    }
    return r;
}

- (NSDictionary *)groupBy:(id (^)(id value))keySelector {

    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    for (id item in self) {
        id key = keySelector(item);

        NSMutableArray *group = result[key];
        if (group == nil) {
            group       = [NSMutableArray array];
            result[key] = group;
        }
        [group addObject:item];
    }

    return result;
}

@end

NS_ASSUME_NONNULL_END
