//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "StorageCoordinator.h"
#import "AppReadiness.h"
#import "YDBStorage.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const StorageIsReadyNotification = @"StorageIsReadyNotification";

NSString *NSStringFromStorageCoordinatorState(StorageCoordinatorState value)
{
    switch (value) {
        case StorageCoordinatorStateGRDB:
            return @"StorageCoordinatorStateGRDB";
        case StorageCoordinatorStateGRDBTests:
            return @"StorageCoordinatorStateGRDBTests";
    }
}

NSString *NSStringForDataStore(DataStore value)
{
    switch (value) {
        case DataStoreGrdb:
            return @"DataStoreGrdb";
    }
}

#pragma mark -

@interface StorageCoordinator () <SDSDatabaseStorageDelegate>

@property (atomic) StorageCoordinatorState state;

@property (atomic) BOOL isStorageSetupComplete;

@end

#pragma mark -

@implementation StorageCoordinator

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    _databaseStorage = [[SDSDatabaseStorage alloc] initWithDelegate:self];

    [self configure];

    return self;
}

+ (BOOL)hasYdbFile
{
    BOOL hasYdbFile = YDBStorage.hasAnyYdbFile;

    if (hasYdbFile && !SSKPreferences.didEverUseYdb) {
        [SSKPreferences setDidEverUseYdb:YES];
    }

    return hasYdbFile;
}

+ (BOOL)hasGrdbFile
{
    NSString *grdbFilePath = SDSDatabaseStorage.grdbDatabaseFileUrl.path;
    return [OWSFileSystem fileOrFolderExistsAtPath:grdbFilePath];
}

+ (BOOL)hasInvalidDatabaseVersion
{
    if (SSKPreferences.hasUnknownGRDBSchema) {
        return YES;
    }

    return NO;
}

- (StorageCoordinatorState)storageCoordinatorState
{
    return self.state;
}

- (void)configure
{
    BOOL hasYdbFile = self.class.hasYdbFile;


    switch (SSKFeatureFlags.storageMode) {
        case StorageModeGrdb:
            self.state = StorageCoordinatorStateGRDB;

            if (hasYdbFile) {
                [SSKPreferences setDidEverUseYdb:YES];
                [SSKPreferences setDidDropYdb:YES];
            }

//            if (CurrentAppContext().isMainApp) {
//                [AppReadiness
//                    runNowOrWhenAppDidBecomeReadyAsync:^{
//                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
//                            ^{ [YDBStorage deleteYDBStorage]; });
//                    }
//                                                 label:@"StorageCoordinator.configure"];
//            }
            break;
        case StorageModeGrdbTests:
            self.state = StorageCoordinatorStateGRDBTests;
            break;
    }

}

- (BOOL)isDatabasePasswordAccessible
{
    return [GRDBDatabaseStorageAdapter isKeyAccessible];
}

- (void)markStorageSetupAsComplete
{
    self.isStorageSetupComplete = YES;

    [self postStorageIsReadyNotification];
}

- (void)postStorageIsReadyNotification
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSNotificationCenter defaultCenter] postNotificationNameAsync:StorageIsReadyNotification
                                                                 object:nil
                                                               userInfo:nil];
    });
}

- (BOOL)isStorageReady
{
    switch (self.state) {
        case StorageCoordinatorStateGRDB:
        case StorageCoordinatorStateGRDBTests:
            return self.isStorageSetupComplete;
    }
}

@end

NS_ASSUME_NONNULL_END
