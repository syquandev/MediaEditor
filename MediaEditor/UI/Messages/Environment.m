//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "Environment.h"
#import "OWSPreferences.h"
#import <SignalServiceKit/AppContext.h>
#import <SignalServiceKit/SSKEnvironment.h>

static Environment *sharedEnvironment = nil;

@interface Environment ()

@property (nonatomic) OWSPreferences *preferencesRef;

@end

#pragma mark -

@implementation Environment

+ (Environment *)shared
{

    return sharedEnvironment;
}

+ (void)setShared:(Environment *)environment
{
    // The main app environment should only be set once.
    //
    // App extensions may be opened multiple times in the same process,
    // so statics will persist.

    sharedEnvironment = environment;
}

+ (void)clearSharedForTests
{
    sharedEnvironment = nil;
}

- (instancetype)preferences :(OWSPreferences *)preferences{
    if (!self) {
        return self;
    }
    _preferencesRef = preferences;
    return self;
}

@end
