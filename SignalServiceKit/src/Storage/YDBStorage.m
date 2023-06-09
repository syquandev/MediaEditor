//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "YDBStorage.h"
#import "OWSFileSystem.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *keychainService = @"TSKeyChainService";
static NSString *keychainDBLegacyPassphrase = @"TSDatabasePass";
static NSString *keychainDBCipherKeySpec = @"OWSDatabaseCipherKeySpec";

#pragma mark -

@implementation YDBStorage

+ (NSString *)legacyDatabaseDirPath
{
    return [OWSFileSystem appDocumentDirectoryPath];
}

+ (NSString *)sharedDataDatabaseDirPath
{
    return [[OWSFileSystem appSharedDataDirectoryPath] stringByAppendingPathComponent:@"database"];
}

+ (NSString *)databaseFilename
{
    return @"Signal.sqlite";
}

+ (NSString *)databaseFilename_SHM
{
    return [self.databaseFilename stringByAppendingString:@"-shm"];
}

+ (NSString *)databaseFilename_WAL
{
    return [self.databaseFilename stringByAppendingString:@"-wal"];
}

+ (NSString *)legacyDatabaseFilePath
{
    return [self.legacyDatabaseDirPath stringByAppendingPathComponent:self.databaseFilename];
}

+ (NSString *)legacyDatabaseFilePath_SHM
{
    return [self.legacyDatabaseDirPath stringByAppendingPathComponent:self.databaseFilename_SHM];
}

+ (NSString *)legacyDatabaseFilePath_WAL
{
    return [self.legacyDatabaseDirPath stringByAppendingPathComponent:self.databaseFilename_WAL];
}

+ (NSString *)sharedDataDatabaseFilePath
{
    return [self.sharedDataDatabaseDirPath stringByAppendingPathComponent:self.databaseFilename];
}

+ (NSString *)sharedDataDatabaseFilePath_SHM
{
    return [self.sharedDataDatabaseDirPath stringByAppendingPathComponent:self.databaseFilename_SHM];
}

+ (NSString *)sharedDataDatabaseFilePath_WAL
{
    return [self.sharedDataDatabaseDirPath stringByAppendingPathComponent:self.databaseFilename_WAL];
}

#pragma mark -

+ (void)deleteYDBStorage
{
    [self deleteDatabaseFiles];
    [self deleteDBKeys];
}

+ (void)deleteDatabaseFiles
{
    [OWSFileSystem deleteFileIfExists:self.legacyDatabaseFilePath];
    [OWSFileSystem deleteFileIfExists:self.legacyDatabaseFilePath_SHM];
    [OWSFileSystem deleteFileIfExists:self.legacyDatabaseFilePath_WAL];
    [OWSFileSystem deleteFileIfExists:self.sharedDataDatabaseFilePath];
    [OWSFileSystem deleteFileIfExists:self.sharedDataDatabaseFilePath_SHM];
    [OWSFileSystem deleteFileIfExists:self.sharedDataDatabaseFilePath_WAL];
    // NOTE: It's NOT safe to delete OWSPrimaryStorage.legacyDatabaseDirPath
    //       which is the app document dir.
    [OWSFileSystem deleteContentsOfDirectory:self.sharedDataDatabaseDirPath];
}

+ (BOOL)hasAnyYdbFile
{
    return ([OWSFileSystem fileOrFolderExistsAtPath:self.legacyDatabaseFilePath] ||
        [OWSFileSystem fileOrFolderExistsAtPath:self.legacyDatabaseFilePath_SHM] ||
        [OWSFileSystem fileOrFolderExistsAtPath:self.legacyDatabaseFilePath_WAL] ||
        [OWSFileSystem fileOrFolderExistsAtPath:self.sharedDataDatabaseFilePath] ||
        [OWSFileSystem fileOrFolderExistsAtPath:self.sharedDataDatabaseFilePath_SHM] ||
        [OWSFileSystem fileOrFolderExistsAtPath:self.sharedDataDatabaseFilePath_WAL]);
}

#pragma mark - Keychain

+ (void)deleteDBKeys
{
    NSError *_Nullable error;
    BOOL result = [CurrentAppContext().keychainStorage removeWithService:keychainService
                                                                     key:keychainDBLegacyPassphrase
                                                                   error:&error];
    result = [CurrentAppContext().keychainStorage removeWithService:keychainService
                                                                key:keychainDBCipherKeySpec
                                                              error:&error];
}


@end

NS_ASSUME_NONNULL_END
