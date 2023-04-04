//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "NSUserDefaults+OWS.h"
#import "AppContext.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation NSUserDefaults (OWS)

+ (NSUserDefaults *)appUserDefaults
{
    return CurrentAppContext().appUserDefaults;
}

+ (void)removeAll
{
    [NSUserDefaults.standardUserDefaults removeAll];
    [self.appUserDefaults removeAll];
}

- (void)removeAll
{

    NSDictionary<NSString *, id> *dictionary = self.dictionaryRepresentation;
    for (NSString *key in dictionary) {
        [self removeObjectForKey:key];
    }
    [self synchronize];
}

@end

NS_ASSUME_NONNULL_END
