//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "OWSFileSystem.h"
#import "OWSError.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation OWSFileSystem

+ (BOOL)protectRecursiveContentsAtPath:(NSString *)path
{
    BOOL isDirectory;
    if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory]) {
        return NO;
    }

    if (!isDirectory) {
        return [self protectFileOrFolderAtPath:path];
    }
    NSString *dirPath = path;

    BOOL success = YES;
    NSDirectoryEnumerator *directoryEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:dirPath];

    for (NSString *relativePath in directoryEnumerator) {
        NSString *filePath = [dirPath stringByAppendingPathComponent:relativePath];

        success = success && [self protectFileOrFolderAtPath:filePath];
    }

    return success;
}

+ (BOOL)protectFileOrFolderAtPath:(NSString *)path
{
    return
        [self protectFileOrFolderAtPath:path fileProtectionType:NSFileProtectionCompleteUntilFirstUserAuthentication];
}

+ (BOOL)protectFileOrFolderAtPath:(NSString *)path fileProtectionType:(NSFileProtectionType)fileProtectionType
{
    if (!SSKDebugFlags.reduceLogChatter) {
    }
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
        return NO;
    }

    NSError *_Nullable error;
    NSDictionary *fileProtection = @{ NSFileProtectionKey : fileProtectionType };
    BOOL success = [[NSFileManager defaultManager] setAttributes:fileProtection ofItemAtPath:path error:&error];
    if (error || !success) {
        if (error != nil && [error.domain isEqualToString:NSCocoaErrorDomain]
            && (error.code == NSFileReadNoSuchFileError || error.code == NSFileNoSuchFileError)) {
            // We sometimes protect files async, so races around short-lived
            // temporarily files can cause these errors.
            return NO;
        }
        OWSProdCritical([OWSAnalyticsEvents storageErrorFileProtection]);
        return NO;
    }

    NSDictionary *resourcesAttrs = @{ NSURLIsExcludedFromBackupKey : @YES };

    NSURL *ressourceURL = [NSURL fileURLWithPath:path];
    success = [ressourceURL setResourceValues:resourcesAttrs error:&error];

    if (error || !success) {
        if (error != nil && [error.domain isEqualToString:NSCocoaErrorDomain]
            && (error.code == NSFileReadNoSuchFileError || error.code == NSFileNoSuchFileError)) {
            // We sometimes protect files async, so races around short-lived
            // temporarily files can cause these errors.
            return NO;
        }
        OWSProdCritical([OWSAnalyticsEvents storageErrorFileProtection]);
        return NO;
    }
    return YES;
}

+ (void)logAttributesOfItemAtPathRecursively:(NSString *)path
{
    BOOL isDirectory;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
    if (!exists) {
        return;
    }
}

+ (NSString *)appLibraryDirectoryPath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentDirectoryURL =
        [[fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    return [documentDirectoryURL path];
}

+ (NSString *)appDocumentDirectoryPath
{
    return CurrentAppContext().appDocumentDirectoryPath;
}

+ (NSURL *)appSharedDataDirectoryURL
{
    return [NSURL fileURLWithPath:self.appSharedDataDirectoryPath];
}

+ (NSString *)appSharedDataDirectoryPath
{
    return CurrentAppContext().appSharedDataDirectoryPath;
}

+ (NSString *)cachesDirectoryPath
{
    static NSString *result;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        result = paths[0];
    });
    return result;
}

+ (nullable NSError *)renameFilePathUsingRandomExtension:(NSString *)oldFilePath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:oldFilePath]) {
        return nil;
    }
    return nil;
}

+ (nullable NSError *)moveAppFilePath:(NSString *)oldFilePath sharedDataFilePath:(NSString *)newFilePath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:oldFilePath]) {
        return nil;
    }

    if ([fileManager fileExistsAtPath:newFilePath]) {
        // If a file/directory already exists at the destination,
        // try to move it "aside" by renaming it with an extension.
        NSError *_Nullable error = [self renameFilePathUsingRandomExtension:newFilePath];
        if (error) {
            return error;
        }
    }

    if ([fileManager fileExistsAtPath:newFilePath]) {
        return [OWSError withError:OWSErrorCodeMoveFileToSharedDataContainerError
                       description:@"Can't move file; destination already exists."
                       isRetryable:NO];
    }
    
    NSError *_Nullable error;
    BOOL success = [fileManager moveItemAtPath:oldFilePath toPath:newFilePath error:&error];
    if (!success || error) {
        return error;
    }

    // Ensure all files moved have the proper data protection class.
    // On large directories this can take a while, so we dispatch async
    // since we're in the launch path.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self protectRecursiveContentsAtPath:newFilePath];
    });

    return nil;
}

+ (BOOL)moveFilePath:(NSString *)oldFilePath toFilePath:(NSString *)newFilePath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:oldFilePath]) {
        return NO;
    }

    if ([fileManager fileExistsAtPath:newFilePath]) {
        return NO;
    }

    NSError *_Nullable error;
    BOOL success = [fileManager moveItemAtPath:oldFilePath toPath:newFilePath error:&error];
    if (!success || error) {
        return NO;
    }

    // Ensure all files moved have the proper data protection class.
    // On large directories this can take a while, so we dispatch async
    // since we're in the launch path.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self protectRecursiveContentsAtPath:newFilePath];
    });

    return YES;
}

+ (BOOL)ensureDirectoryExists:(NSString *)dirPath
{
    return [self ensureDirectoryExists:dirPath fileProtectionType:NSFileProtectionCompleteUntilFirstUserAuthentication];
}

+ (BOOL)ensureDirectoryExists:(NSString *)dirPath fileProtectionType:(NSFileProtectionType)fileProtectionType
{
    BOOL isDirectory;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:dirPath isDirectory:&isDirectory];
    if (exists) {

        return [self protectFileOrFolderAtPath:dirPath fileProtectionType:fileProtectionType];
    } else {

        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:dirPath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        if (error) {
            return NO;
        }
        return [self protectFileOrFolderAtPath:dirPath fileProtectionType:fileProtectionType];
    }
}

+ (BOOL)ensureFileExists:(NSString *)filePath
{
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
    if (exists) {
        return [self protectFileOrFolderAtPath:filePath];
    } else {
        BOOL success = [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
        if (!success) {
            return NO;
        }
        return [self protectFileOrFolderAtPath:filePath];
    }
}

+ (void)deleteContentsOfDirectory:(NSString *)dirPath
{
    NSArray<NSString *> *_Nullable filePaths = [self recursiveFilesInDirectory:dirPath error:NULL];
    if (filePaths == nil) {
        return;
    }
    for (NSString *filePath in filePaths) {
        [self deleteFileIfExists:filePath];
    }
}

+ (nullable NSNumber *)fileSizeOfPath:(NSString *)filePath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *_Nullable error;
    unsigned long long fileSize =
        [[fileManager attributesOfItemAtPath:filePath error:&error][NSFileSize] unsignedLongLongValue];
    if (error) {
        return nil;
    } else {
        return @(fileSize);
    }
}

+ (nullable NSNumber *)fileSizeOfUrl:(NSURL *)fileUrl
{
    return [self fileSizeOfPath:fileUrl.path];
}

@end

#pragma mark -

NSString *OWSTemporaryDirectory(void)
{
    static NSString *dirPath;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *dirName = [NSString stringWithFormat:@"ows_temp_%@", NSUUID.UUID.UUIDString];
        dirPath = [NSTemporaryDirectory() stringByAppendingPathComponent:dirName];
    });
    return dirPath;
}

NSString *OWSTemporaryDirectoryAccessibleAfterFirstAuth(void)
{
    NSString *dirPath = NSTemporaryDirectory();
    return dirPath;
}

void ClearOldTemporaryDirectoriesSync(void)
{
    // Ignore the "current" temp directory.
    NSString *currentTempDirName = OWSTemporaryDirectory().lastPathComponent;

    NSDate *thresholdDate = CurrentAppContext().appLaunchTime;
    NSString *dirPath = NSTemporaryDirectory();
    NSError *error;
    NSArray<NSString *> *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dirPath error:&error];
    if (error) {
        return;
    }
    for (NSString *fileName in fileNames) {
        if (!CurrentAppContext().isAppForegroundAndActive) {
            // Abort if app not active.
            return;
        }
        if ([fileName isEqualToString:currentTempDirName]) {
            continue;
        }

        NSString *filePath = [dirPath stringByAppendingPathComponent:fileName];

        // Delete files with either:
        //
        // a) "ows_temp" name prefix.
        // b) modified time before app launch time.
        if (![fileName hasPrefix:@"ows_temp"]) {
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
        }

        if (![OWSFileSystem deleteFileIfExists:filePath]) {
        }
    }
}

// NOTE: We need to call this method on launch _and_ every time the app becomes active,
//       since file protection may prevent it from succeeding in the background.
void ClearOldTemporaryDirectories(void)
{
    // We use the lowest priority queue for this, and wait N seconds
    // to avoid interfering with app startup.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.f * NSEC_PER_SEC)),
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
        ^{
            ClearOldTemporaryDirectoriesSync();
        });
}

NS_ASSUME_NONNULL_END
