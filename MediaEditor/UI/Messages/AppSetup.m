//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

#import "AppSetup.h"
#import "Environment.h"
#import "VersionMigrations.h"
#import <MediaEditor-Swift.h>
#import <SignalServiceKit/OWS2FAManager.h>
#import <SignalServiceKit/OWSBackgroundTask.h>
#import <SignalServiceKit/OWSIdentityManager.h>
#import <SignalServiceKit/SSKEnvironment.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation AppSetup

+ (void)appSpecificSingletonBlock:(NS_NOESCAPE dispatch_block_t)appSpecificSingletonBlock
                       migrationCompletion:(void (^)(NSError *_Nullable error))migrationCompletion
{
    [self suppressUnsatisfiableConstraintLogging];

    __block OWSBackgroundTask *_Nullable backgroundTask =
        [OWSBackgroundTask backgroundTaskWithLabelStr:__PRETTY_FUNCTION__];

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Order matters here.
        //
        // All of these "singletons" should have any dependencies used in their
        // initializers injected.
        [[OWSBackgroundTaskManager shared] observeNotifications];

        // AFNetworking (via CFNetworking) spools it's attachments to NSTemporaryDirectory().
        // If you receive a media message while the device is locked, the download will fail if the temporary directory
        // is NSFileProtectionComplete
        BOOL success;
        NSString *temporaryDirectory = NSTemporaryDirectory();
        success = YES;

        OWSPreferences *preferences = [OWSPreferences new];
        
//        StorageCoordinator *storageCoordinator = [StorageCoordinator new];
//        SDSDatabaseStorage *databaseStorage = storageCoordinator.databaseStorage;
        
        OWSLinkPreviewManager *linkPreviewManager = [OWSLinkPreviewManager new];
        id<RemoteConfigManager> remoteConfigManager = [ServiceRemoteConfigManager new];
        id<OWSUDManager> udManager = [OWSUDManagerImpl new];
        OWS2FAManager *ows2FAManager = [OWS2FAManager new];
        id<OWSTypingIndicators> typingIndicators = [[OWSTypingIndicatorsImpl alloc] init];
        OWSAttachmentDownloads *attachmentDownloads = [[OWSAttachmentDownloads alloc] init];
        SignalServiceAddressCache *signalServiceAddressCache = [SignalServiceAddressCache new];
        SSKPreferences *sskPreferences = [SSKPreferences new];
        SenderKeyStore *senderKeyStore = [[SenderKeyStore alloc] init];

        id<OWSProximityMonitoringManager> proximityMonitoringManager = [OWSProximityMonitoringManagerImpl new];
        BulkProfileFetch *bulkProfileFetch = [BulkProfileFetch new];
        BulkUUIDLookup *bulkUUIDLookup = [BulkUUIDLookup new];\
        ModelReadCaches *modelReadCaches =
            [[ModelReadCaches alloc] initWithModelReadCacheFactory:[ModelReadCacheFactory new]];
        AppExpiry *appExpiry = [AppExpiry new];
        OWSOrphanDataCleaner *orphanDataCleaner = [OWSOrphanDataCleaner new];
        ChangePhoneNumber *changePhoneNumber = [ChangePhoneNumber new];
        
        [Environment setShared:[[Environment alloc] preferences: preferences]];

        [SSKEnvironment setShared:[[SSKEnvironment alloc] initWithContactsManager:nil
                                                               linkPreviewManager:linkPreviewManager
                                                              remoteConfigManager:remoteConfigManager
                                                           aciSignalProtocolStore:nil
                                                           pniSignalProtocolStore:nil
                                                                        udManager:udManager
                                                                    ows2FAManager:ows2FAManager
                                                                 typingIndicators:typingIndicators
                                                              attachmentDownloads:attachmentDownloads
                                                        signalServiceAddressCache:signalServiceAddressCache
                                                                   sskPreferences:sskPreferences
                                                                 bulkProfileFetch:bulkProfileFetch
                                                                   bulkUUIDLookup:bulkUUIDLookup
                                                                  modelReadCaches:modelReadCaches
                                                                        appExpiry:appExpiry
                                                                   senderKeyStore:senderKeyStore
                                                                changePhoneNumber:changePhoneNumber]];

        appSpecificSingletonBlock();
        
        [NSKeyedUnarchiver setClass:[ExperienceUpgrade class] forClassName:[ExperienceUpgrade collection]];
        [NSKeyedUnarchiver setClass:[ExperienceUpgrade class] forClassName:@"Signal.ExperienceUpgrade"];
        [NSKeyedUnarchiver setClass:[TSGroupModelV2 class] forClassName:@"TSGroupModelV2"];


        // Prevent device from sleeping during migrations.
        // This protects long migrations (e.g. the YDB-to-GRDB migration)
        // from the iOS 13 background crash.
        //
        // We can use any object.
        NSObject *sleepBlockObject = [NSObject new];
        [DeviceSleepManager.shared addBlockWithBlockObject:sleepBlockObject];

        dispatch_block_t completionBlock = ^{
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                if (AppSetup.shouldTruncateGrdbWal) {
                    // Try to truncate GRDB WAL before any readers or writers are
                    // active.
                    NSError *_Nullable error;
//                    [databaseStorage.grdbStorage syncTruncatingCheckpointAndReturnError:&error];
                    if (error != nil) {

                        dispatch_async(dispatch_get_main_queue(), ^{ migrationCompletion(error); });
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
//                    [storageCoordinator markStorageSetupAsComplete];

                    // Don't start database migrations until storage is ready.
                    [VersionMigrations performUpdateCheckWithCompletion:^() {
                        OWSAssertIsOnMainThread();

                        [DeviceSleepManager.shared removeBlockWithBlockObject:sleepBlockObject];

                        [SSKEnvironment.shared warmCaches];
                        migrationCompletion(nil);

                        OWSAssertDebug(backgroundTask);
                        backgroundTask = nil;
                    }];
                });

                // Do this after we've let the main thread know that storage setup is complete.
                if (SSKDebugFlags.internalLogging) {
                    [SDSKeyValueStore logCollectionStatistics];
                }
            });
        };

        completionBlock();
    });
}

+ (void)suppressUnsatisfiableConstraintLogging
{
    [[NSUserDefaults standardUserDefaults] setValue:@(SSKDebugFlags.internalLogging)
                                             forKey:@"_UIConstraintBasedLayoutLogUnsatisfiable"];
}

+ (BOOL)shouldTruncateGrdbWal
{
    if (!CurrentAppContext().isMainApp) {
        return NO;
    }
    if (CurrentAppContext().mainApplicationStateOnLaunch == UIApplicationStateBackground) {
        return NO;
    }
    return YES;
}

@end

NS_ASSUME_NONNULL_END
