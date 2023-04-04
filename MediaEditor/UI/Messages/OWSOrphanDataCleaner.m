//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

#import "OWSOrphanDataCleaner.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import <MediaEditor-Swift.h>
#import <SignalServiceKit/AppReadiness.h>
#import <SignalServiceKit/AppVersion.h>
#import <SignalServiceKit/OWSFileSystem.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>
#import <SignalServiceKit/TSAttachmentStream.h>
#import <SignalServiceKit/TSInteraction.h>
#import <SignalServiceKit/TSMessage.h>
#import <SignalServiceKit/TSThread.h>

NS_ASSUME_NONNULL_BEGIN

// LOG_ALL_FILE_PATHS can be used to determine if there are other kinds of files
// that we're not cleaning up.
//#define LOG_ALL_FILE_PATHS

NSString *const OWSOrphanDataCleaner_LastCleaningVersionKey = @"OWSOrphanDataCleaner_LastCleaningVersionKey";
NSString *const OWSOrphanDataCleaner_LastCleaningDateKey = @"OWSOrphanDataCleaner_LastCleaningDateKey";

@interface OWSOrphanData : NSObject

@property (nonatomic) NSSet<NSString *> *interactionIds;
@property (nonatomic) NSSet<NSString *> *attachmentIds;
@property (nonatomic) NSSet<NSString *> *filePaths;
@property (nonatomic) NSSet<NSString *> *reactionIds;
@property (nonatomic) NSSet<NSString *> *mentionIds;

@end

#pragma mark -

@implementation OWSOrphanData

@end

#pragma mark -

typedef void (^OrphanDataBlock)(OWSOrphanData *);

@implementation OWSOrphanDataCleaner

- (instancetype)init
{
    self = [super init];

    if (!self) {
        return self;
    }

//    AppReadinessRunNowOrWhenMainAppDidBecomeReadyAsync(^{ [OWSOrphanDataCleaner auditOnLaunchIfNecessary]; });

    return self;
}

+ (SDSKeyValueStore *)keyValueStore
{
    static SDSKeyValueStore *keyValueStore = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *const OWSOrphanDataCleaner_Collection = @"OWSOrphanDataCleaner_Collection";
        keyValueStore = [[SDSKeyValueStore alloc] initWithCollection:OWSOrphanDataCleaner_Collection];
    });
    return keyValueStore;
}

// Unlike CurrentAppContext().isMainAppAndActive, this method can be safely
// invoked off the main thread.
+ (BOOL)isMainAppAndActive
{
    return CurrentAppContext().reportedApplicationState == UIApplicationStateActive;
}

+ (void)printPaths:(NSArray<NSString *> *)paths label:(NSString *)label
{
}

+ (long long)fileSizeOfFilePath:(NSString *)filePath
{
    NSError *error;
    NSNumber *fileSize = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error][NSFileSize];
    return fileSize.longLongValue;
}

+ (nullable NSNumber *)fileSizeOfFilePathsSafe:(NSArray<NSString *> *)filePaths
{
    long long result = 0;
    for (NSString *filePath in filePaths) {
        if (!self.isMainAppAndActive) {
            return nil;
        }
        result += [self fileSizeOfFilePath:filePath];
    }
    return @(result);
}

+ (nullable NSSet<NSString *> *)filePathsInDirectorySafe:(NSString *)dirPath
{
    NSMutableSet *filePaths = [NSMutableSet new];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dirPath]) {
        return filePaths;
    }
    NSError *error;
    NSArray<NSString *> *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dirPath error:&error];
    
    for (NSString *fileName in fileNames) {
        if (!self.isMainAppAndActive) {
            return nil;
        }
        NSString *filePath = [dirPath stringByAppendingPathComponent:fileName];
        BOOL isDirectory;
        [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory];
        if (isDirectory) {
            NSSet<NSString *> *_Nullable dirPaths = [self filePathsInDirectorySafe:filePath];
            if (!dirPaths) {
                return nil;
            }
            [filePaths unionSet:dirPaths];
        } else {
            [filePaths addObject:filePath];
        }
    }
    return filePaths;
}

// This method finds (but does not delete):
//
// * Orphan TSInteractions (with no thread).
// * Orphan TSAttachments (with no message).
// * Orphan attachment files (with no corresponding TSAttachment).
// * Orphan profile avatars.
// * Temporary files (all).
//
// It also finds (we don't clean these up).
//
// * Missing attachment files (cannot be cleaned up).
//   These are attachments which have no file on disk.  They should be extremely rare -
//   the only cases I have seen are probably due to debugging.
//   They can't be cleaned up - we don't want to delete the TSAttachmentStream or
//   its corresponding message.  Better that the broken message shows up in the
//   conversation view.
+ (void)findOrphanDataWithRetries:(NSInteger)remainingRetries
                          success:(OrphanDataBlock)success
                          failure:(dispatch_block_t)failure
{
    if (remainingRetries < 1) {
        dispatch_async(self.workQueue, ^{
            failure();
        });
        return;
    }

    // Wait until the app is active...
    [CurrentAppContext() runNowOrWhenMainAppIsActive:^{
        // ...but perform the work off the main thread.
        dispatch_async(self.workQueue, ^{
            OWSOrphanData *_Nullable orphanData = [self findOrphanDataSync];
            if (orphanData) {
                success(orphanData);
            } else {
                [self findOrphanDataWithRetries:remainingRetries - 1
                                        success:success
                                        failure:failure];
            }
        });
    }];
}

// Returns nil on failure, usually indicating that the search
// aborted due to the app resigning active.  This method is extremely careful to
// abort if the app resigns active, in order to avoid 0xdead10cc crashes.
+ (nullable OWSOrphanData *)findOrphanDataSync
{
    __block BOOL shouldAbort = NO;

#ifdef LOG_ALL_FILE_PATHS
    {
        NSString *documentDirPath = [OWSFileSystem appDocumentDirectoryPath];
        NSArray<NSString *> *_Nullable allDocumentFilePaths =
            [self filePathsInDirectorySafe:documentDirPath].allObjects;
        allDocumentFilePaths = [allDocumentFilePaths sortedArrayUsingSelector:@selector(compare:)];
        NSString *attachmentsFolder = [TSAttachmentStream attachmentsFolder];
        for (NSString *filePath in allDocumentFilePaths) {
            if ([filePath hasPrefix:attachmentsFolder]) {
                continue;
            }
            OWSLogVerbose(@"non-attachment file: %@", filePath);
        }
    }
    {
        NSString *documentDirPath = [OWSFileSystem appSharedDataDirectoryPath];
        NSArray<NSString *> *_Nullable allDocumentFilePaths =
            [self filePathsInDirectorySafe:documentDirPath].allObjects;
        allDocumentFilePaths = [allDocumentFilePaths sortedArrayUsingSelector:@selector(compare:)];
        NSString *attachmentsFolder = [TSAttachmentStream attachmentsFolder];
        for (NSString *filePath in allDocumentFilePaths) {
            if ([filePath hasPrefix:attachmentsFolder]) {
                continue;
            }
            OWSLogVerbose(@"non-attachment file: %@", filePath);
        }
    }
#endif

    // We treat _all_ temp files as orphan files.  This is safe
    // because temp files only need to be retained for the
    // a single launch of the app.  Since our "date threshold"
    // for deletion is relative to the current launch time,
    // all temp files currently in use should be safe.
    NSArray<NSString *> *_Nullable tempFilePaths = [self getTempFilePaths];
    if (!tempFilePaths || !self.isMainAppAndActive) {
        return nil;
    }

#ifdef LOG_ALL_FILE_PATHS
    {
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        [dateFormatter setDateStyle:NSDateFormatterLongStyle];
        [dateFormatter setTimeStyle:NSDateFormatterLongStyle];

        tempFilePaths = [tempFilePaths sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *filePath in tempFilePaths) {
            NSError *error;
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error];
            if (!attributes || error) {
                OWSLogDebug(@"Could not get attributes of file at: %@", filePath);
                OWSFailDebug(@"Could not get attributes of file");
                continue;
            }
            OWSLogVerbose(
                @"temp file: %@, %@", filePath, [dateFormatter stringFromDate:attributes.fileModificationDate]);
        }
    }
#endif

    NSString *legacyAttachmentsDirPath = TSAttachmentStream.legacyAttachmentsDirPath;
    NSString *sharedDataAttachmentsDirPath = TSAttachmentStream.sharedDataAttachmentsDirPath;
    NSSet<NSString *> *_Nullable legacyAttachmentFilePaths = [self filePathsInDirectorySafe:legacyAttachmentsDirPath];
    if (!legacyAttachmentFilePaths || !self.isMainAppAndActive) {
        return nil;
    }
    NSSet<NSString *> *_Nullable sharedDataAttachmentFilePaths =
        [self filePathsInDirectorySafe:sharedDataAttachmentsDirPath];
    if (!sharedDataAttachmentFilePaths || !self.isMainAppAndActive) {
        return nil;
    }

    NSString *legacyProfileAvatarsDirPath = @"";
    NSString *sharedDataProfileAvatarsDirPath = @"";
    NSSet<NSString *> *_Nullable legacyProfileAvatarsFilePaths =
        [self filePathsInDirectorySafe:legacyProfileAvatarsDirPath];
    if (!legacyProfileAvatarsFilePaths || !self.isMainAppAndActive) {
        return nil;
    }
    NSSet<NSString *> *_Nullable sharedDataProfileAvatarFilePaths =
        [self filePathsInDirectorySafe:sharedDataProfileAvatarsDirPath];
    if (!sharedDataProfileAvatarFilePaths || !self.isMainAppAndActive) {
        return nil;
    }

    NSSet<NSString *> *_Nullable allGroupAvatarFilePaths =
        [self filePathsInDirectorySafe:TSGroupModel.avatarsDirectory.path];
    if (!allGroupAvatarFilePaths || !self.isMainAppAndActive) {
        return nil;
    }

    NSMutableSet<NSString *> *allOnDiskFilePaths = [NSMutableSet new];
    [allOnDiskFilePaths unionSet:legacyAttachmentFilePaths];
    [allOnDiskFilePaths unionSet:sharedDataAttachmentFilePaths];
    [allOnDiskFilePaths unionSet:legacyProfileAvatarsFilePaths];
    [allOnDiskFilePaths unionSet:sharedDataProfileAvatarFilePaths];
    [allOnDiskFilePaths unionSet:allGroupAvatarFilePaths];
    [allOnDiskFilePaths addObjectsFromArray:tempFilePaths];
    // TODO: Badges?

    // This should be redundant, but this will future-proof us against
    // ever accidentally removing the GRDB databases during
    // orphan clean up.
    NSString *grdbPrimaryDirectoryPath =
        [GRDBDatabaseStorageAdapter databaseDirUrlWithDirectoryMode:DirectoryModePrimary].path;
    NSString *grdbHotswapDirectoryPath =
        [GRDBDatabaseStorageAdapter databaseDirUrlWithDirectoryMode:DirectoryModeHotswapLegacy].path;
    NSString *grdbTransferDirectoryPath = nil;

    NSMutableSet<NSString *> *databaseFilePaths = [NSMutableSet new];
    for (NSString *filePath in allOnDiskFilePaths) {
        if ([filePath hasPrefix:grdbPrimaryDirectoryPath]) {
            
            [databaseFilePaths addObject:filePath];
        } else if ([filePath hasPrefix:grdbHotswapDirectoryPath]) {
            
            [databaseFilePaths addObject:filePath];
        } else if (grdbTransferDirectoryPath && [filePath hasPrefix:grdbTransferDirectoryPath]) {
            
            [databaseFilePaths addObject:filePath];
        }
    }
    [allOnDiskFilePaths minusSet:databaseFilePaths];

    __block NSSet<NSString *> *profileAvatarFilePaths;

    __block NSSet<NSString *> *groupAvatarFilePaths;
    __block NSError *groupAvatarFilePathError;

    NSNumber *_Nullable totalFileSize = [self fileSizeOfFilePathsSafe:allOnDiskFilePaths.allObjects];

    if (!totalFileSize || !self.isMainAppAndActive) {
        return nil;
    }

    NSUInteger fileCount = allOnDiskFilePaths.count;

    // Attachments
    __block int attachmentStreamCount = 0;
    NSMutableSet<NSString *> *allAttachmentFilePaths = [NSMutableSet new];
    NSMutableSet<NSString *> *allAttachmentIds = [NSMutableSet new];
    // Reactions
    NSMutableSet<NSString *> *allReactionIds = [NSMutableSet new];
    // Mentions
    NSMutableSet<NSString *> *allMentionIds = [NSMutableSet new];
    // Threads
    __block NSSet *threadIds;
    // Messages
    NSMutableSet<NSString *> *orphanInteractionIds = [NSMutableSet new];
    NSMutableSet<NSString *> *allMessageAttachmentIds = [NSMutableSet new];
    NSMutableSet<NSString *> *allStoryAttachmentIds = [NSMutableSet new];
    NSMutableSet<NSString *> *allMessageReactionIds = [NSMutableSet new];
    NSMutableSet<NSString *> *allMessageMentionIds = [NSMutableSet new];
    // Stickers
    NSMutableSet<NSString *> *activeStickerFilePaths = [NSMutableSet new];
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        [TSAttachmentStream
            anyEnumerateWithTransaction:transaction
                                batched:YES
                                  block:^(TSAttachment *attachment, BOOL *stop) {
                                      if (!self.isMainAppAndActive) {
                                          shouldAbort = YES;
                                          *stop = YES;
                                          return;
                                      }
                                      if (![attachment isKindOfClass:[TSAttachmentStream class]]) {
                                          return;
                                      }
                                      [allAttachmentIds addObject:attachment.uniqueId];

                                      TSAttachmentStream *attachmentStream = (TSAttachmentStream *)attachment;
                                      attachmentStreamCount++;
                                      NSString *_Nullable filePath = [attachmentStream originalFilePath];
                                      if (filePath) {
                                          [allAttachmentFilePaths addObject:filePath];
                                      }

                                      [allAttachmentFilePaths
                                          addObjectsFromArray:attachmentStream.allSecondaryFilePaths];
                                  }];

        if (shouldAbort) {
            return;
        }

        threadIds = [NSSet setWithArray:[TSThread anyAllUniqueIdsWithTransaction:transaction]];

        NSMutableSet<NSString *> *allInteractionIds = [NSMutableSet new];
        [TSInteraction anyEnumerateWithTransaction:transaction
                                           batched:YES
                                             block:^(TSInteraction *interaction, BOOL *stop) {
                                                 if (!self.isMainAppAndActive) {
                                                     shouldAbort = YES;
                                                     *stop = YES;
                                                     return;
                                                 }
                                                 if (interaction.uniqueThreadId.length < 1
                                                     || ![threadIds containsObject:interaction.uniqueThreadId]) {
                                                     [orphanInteractionIds addObject:interaction.uniqueId];
                                                 }

                                                 [allInteractionIds addObject:interaction.uniqueId];
                                                 if (![interaction isKindOfClass:[TSMessage class]]) {
                                                     return;
                                                 }

                                                 TSMessage *message = (TSMessage *)interaction;
                                                 [allMessageAttachmentIds addObjectsFromArray:message.allAttachmentIds];
                                             }];

        if (shouldAbort) {
            return;
        }

        if (shouldAbort) {
            return;
        }

        [TSMention anyEnumerateWithTransaction:transaction
                                       batched:YES
                                         block:^(TSMention *mention, BOOL *stop) {
                                             if (!self.isMainAppAndActive) {
                                                 shouldAbort = YES;
                                                 *stop = YES;
                                                 return;
                                             }
                                             if (![mention isKindOfClass:[TSMention class]]) {
                                                 return;
                                             }
                                             [allMentionIds addObject:mention.uniqueId];
                                             if ([allInteractionIds containsObject:mention.uniqueMessageId]) {
                                                 [allMessageMentionIds addObject:mention.uniqueId];
                                             }
                                         }];

        if (shouldAbort) {
            return;
        }

        if (shouldAbort) {
            return;
        }

        if (shouldAbort) {
            return;
        }
    }];
    if (shouldAbort) {
        return nil;
    }

    NSMutableSet<NSString *> *orphanFilePaths = [allOnDiskFilePaths mutableCopy];
    [orphanFilePaths minusSet:allAttachmentFilePaths];
    [orphanFilePaths minusSet:profileAvatarFilePaths];
    [orphanFilePaths minusSet:groupAvatarFilePaths];
    [orphanFilePaths minusSet:activeStickerFilePaths];
    NSMutableSet<NSString *> *missingAttachmentFilePaths = [allAttachmentFilePaths mutableCopy];
    [missingAttachmentFilePaths minusSet:allOnDiskFilePaths];

    [self printPaths:orphanFilePaths.allObjects label:@"orphan file paths"];
    [self printPaths:missingAttachmentFilePaths.allObjects label:@"missing attachment file paths"];

    NSMutableSet<NSString *> *orphanAttachmentIds = [allAttachmentIds mutableCopy];
    [orphanAttachmentIds minusSet:allMessageAttachmentIds];
    [orphanAttachmentIds minusSet:allStoryAttachmentIds];
    NSMutableSet<NSString *> *missingAttachmentIds = [allMessageAttachmentIds mutableCopy];
    [missingAttachmentIds minusSet:allAttachmentIds];

    NSMutableSet<NSString *> *orphanReactionIds = [allReactionIds mutableCopy];
    [orphanReactionIds minusSet:allMessageReactionIds];
    NSMutableSet<NSString *> *missingReactionIds = [allMessageReactionIds mutableCopy];
    [missingReactionIds minusSet:allReactionIds];

    NSMutableSet<NSString *> *orphanMentionIds = [allMentionIds mutableCopy];
    [orphanMentionIds minusSet:allMessageMentionIds];
    NSMutableSet<NSString *> *missingMentionIds = [allMessageMentionIds mutableCopy];
    [missingMentionIds minusSet:allMentionIds];

    OWSOrphanData *result = [OWSOrphanData new];
    result.interactionIds = [orphanInteractionIds copy];
    result.attachmentIds = [orphanAttachmentIds copy];
    result.filePaths = [orphanFilePaths copy];
    result.reactionIds = [orphanReactionIds copy];
    result.mentionIds = [orphanMentionIds copy];
    return result;
}

+ (BOOL)shouldAuditOnLaunch
{
    __block NSString *_Nullable lastCleaningVersion;
    __block NSDate *_Nullable lastCleaningDate;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        lastCleaningVersion =
            [self.keyValueStore getString:OWSOrphanDataCleaner_LastCleaningVersionKey transaction:transaction];
        lastCleaningDate =
            [self.keyValueStore getDate:OWSOrphanDataCleaner_LastCleaningDateKey transaction:transaction];
    } file:__FILE__ function:__FUNCTION__ line:__LINE__];

    // Clean up once per app version.
    NSString *currentAppReleaseVersion = self.appVersion.currentAppReleaseVersion;
    if (!lastCleaningVersion || ![lastCleaningVersion isEqualToString:currentAppReleaseVersion]) {
        return YES;
    }

    return NO;
}

+ (void)auditOnLaunchIfNecessary
{

    if (![self shouldAuditOnLaunch]) {
        return;
    }

    // If we want to be cautious, we can disable orphan deletion using
    // flag - the cleanup will just be a dry run with logging.
    BOOL shouldRemoveOrphans = YES;
    [self auditAndCleanup:shouldRemoveOrphans completion:nil];
}

+ (void)auditAndCleanup:(BOOL)shouldRemoveOrphans
{
    [self auditAndCleanup:shouldRemoveOrphans
               completion:^{
               }];
}

// We use the lowest priority possible.
+ (dispatch_queue_t)workQueue
{
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
}

+ (void)auditAndCleanup:(BOOL)shouldRemoveOrphans
             completion:(nullable dispatch_block_t)completion
{

    if (!AppReadiness.isAppReady) {
        return;
    }
    if (!CurrentAppContext().isMainApp) {
        return;
    }
    if (CurrentAppContext().isRunningTests) {
        return;
    }
    if (SSKDebugFlags.suppressBackgroundActivity) {
        // Don't clean up.
        return;
    }

    // Orphan cleanup has two risks:
    //
    // * As a long-running process that involves access to the
    //   shared data container, it could cause 0xdead10cc.
    // * It could accidentally delete data still in use,
    //   e.g. a profile avatar which has been saved to disk
    //   but whose OWSUserProfile hasn't been saved yet.
    //
    // To prevent 0xdead10cc, the cleaner continually checks
    // whether the app has resigned active.  If so, it aborts.
    // Each phase (search, re-search, processing) retries N times,
    // then gives up until the next app launch.
    //
    // To prevent accidental data deletion, we take the following
    // measures:
    //
    // * Only cleanup data of the following types (which should
    //   include all relevant app data): profile avatar,
    //   attachment, temporary files (including temporary
    //   attachments).
    // * We don't delete any data created more recently than N seconds
    //   _before_ when the app launched.  This prevents any stray data
    //   currently in use by the app from being accidentally cleaned
    //   up.
    const NSInteger kMaxRetries = 3;
    [self findOrphanDataWithRetries:kMaxRetries
        success:^(OWSOrphanData *orphanData) {
            [self processOrphans:orphanData
                remainingRetries:kMaxRetries
                shouldRemoveOrphans:shouldRemoveOrphans
                success:^{

                    if (completion) {
                        completion();
                    }
                }
                failure:^{
                    if (completion) {
                        completion();
                    }
                }];
        }
        failure:^{
            if (completion) {
                completion();
            }
        }];
}

// Returns NO on failure, usually indicating that orphan processing
// aborted due to the app resigning active.  This method is extremely careful to
// abort if the app resigns active, in order to avoid 0xdead10cc crashes.
+ (void)processOrphans:(OWSOrphanData *)orphanData
       remainingRetries:(NSInteger)remainingRetries
    shouldRemoveOrphans:(BOOL)shouldRemoveOrphans
                success:(dispatch_block_t)success
                failure:(dispatch_block_t)failure
{

    if (remainingRetries < 1) {
        dispatch_async(self.workQueue, ^{
            failure();
        });
        return;
    }

    // Wait until the app is active...
    [CurrentAppContext() runNowOrWhenMainAppIsActive:^{
        // ...but perform the work off the main thread.
        dispatch_async(self.workQueue, ^{
            if ([self processOrphansSync:orphanData
                     shouldRemoveOrphans:shouldRemoveOrphans]) {
                success();
                return;
            } else {
                [self processOrphans:orphanData
                       remainingRetries:remainingRetries - 1
                    shouldRemoveOrphans:shouldRemoveOrphans
                                success:success
                                failure:failure];
            }
        });
    }];
}

// Returns NO on failure, usually indicating that orphan processing
// aborted due to the app resigning active.  This method is extremely careful to
// abort if the app resigns active, in order to avoid 0xdead10cc crashes.
+ (BOOL)processOrphansSync:(OWSOrphanData *)orphanData
       shouldRemoveOrphans:(BOOL)shouldRemoveOrphans
{

    if (!self.isMainAppAndActive) {
        return NO;
    }

    __block BOOL shouldAbort = NO;

    // We need to avoid cleaning up new files that are still in the process of
    // being created/written, so we don't clean up anything recent.
    const NSTimeInterval kMinimumOrphanAgeSeconds = CurrentAppContext().isRunningTests ? 0.f : 15 * kMinuteInterval;
    NSDate *appLaunchTime = CurrentAppContext().appLaunchTime;
    NSTimeInterval thresholdTimestamp = appLaunchTime.timeIntervalSince1970 - kMinimumOrphanAgeSeconds;
    NSDate *thresholdDate = [NSDate dateWithTimeIntervalSince1970:thresholdTimestamp];

    if (shouldAbort) {
        return NO;
    }

    NSUInteger filesRemoved = 0;
    NSArray<NSString *> *filePaths = [orphanData.filePaths.allObjects sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *filePath in filePaths) {
        if (!self.isMainAppAndActive) {
            return NO;
        }

        NSError *error;
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error];
        if (!attributes || error) {
            continue;
        }
        // Don't delete files which were created in the last N minutes.
        NSDate *creationDate = attributes.fileModificationDate;
        if ([creationDate isAfterDate:thresholdDate]) {
            continue;
        }
        filesRemoved++;
        if (!shouldRemoveOrphans) {
            continue;
        }
        if (![OWSFileSystem fileOrFolderExistsAtPath:filePath]) {
            // Already removed.
            continue;
        }
        if (![OWSFileSystem deleteFile:filePath ignoreIfMissing:YES]) {
        }
    }

    return YES;
}

+ (nullable NSArray<NSString *> *)getTempFilePaths
{
    NSString *dir1 = OWSTemporaryDirectory();
    NSArray<NSString *> *_Nullable paths1 = [[self filePathsInDirectorySafe:dir1].allObjects mutableCopy];

    NSString *dir2 = OWSTemporaryDirectoryAccessibleAfterFirstAuth();
    NSArray<NSString *> *_Nullable paths2 = [[self filePathsInDirectorySafe:dir2].allObjects mutableCopy];

    if (paths1 && paths2) {
        return [paths1 arrayByAddingObjectsFromArray:paths2];
    } else {
        return nil;
    }
}

@end

NS_ASSUME_NONNULL_END
