//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

#import "OWSIdentityManager.h"
#import "AppContext.h"
#import "AppReadiness.h"
#import "NSData+keyVersionByte.h"
#import "OWSError.h"
#import "OWSFileSystem.h"
#import "OWSRecipientIdentity.h"
#import "SSKEnvironment.h"
#import "TSContactThread.h"
#import "TSGroupThread.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import <SignalCoreKit/SCKExceptionWrapper.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

// Storing our own identity key
static NSString *const kIdentityKeyStore_ACIIdentityKey = @"TSStorageManagerIdentityKeyStoreIdentityKey";
static NSString *const kIdentityKeyStore_PNIIdentityKey = @"TSStorageManagerIdentityKeyStorePNIIdentityKey";

static NSString *keyForIdentity(OWSIdentity identity)
{
    switch (identity) {
        case OWSIdentityACI:
            return kIdentityKeyStore_ACIIdentityKey;
        case OWSIdentityPNI:
            return kIdentityKeyStore_PNIIdentityKey;
    }
}

// Don't trust an identity for sending to unless they've been around for at least this long
static const NSTimeInterval kIdentityKeyStoreNonBlockingSecondsThreshold = 5.0;

// The canonical key includes 32 bytes of identity material plus one byte specifying the key type
const NSUInteger kIdentityKeyLength = 33;

// Cryptographic operations do not use the "type" byte of the identity key, so, for legacy reasons we store just
// the identity material.
// TODO: migrate to storing the full 33 byte representation.
const NSUInteger kStoredIdentityKeyLength = 32;

NSNotificationName const kNSNotificationNameIdentityStateDidChange = @"kNSNotificationNameIdentityStateDidChange";

@interface OWSIdentityManager ()

@property (nonatomic, readonly) SDSKeyValueStore *ownIdentityKeyValueStore;
@property (nonatomic, readonly) SDSKeyValueStore *queuedVerificationStateSyncMessagesKeyValueStore;

@end

#pragma mark -

@implementation OWSIdentityManager

- (instancetype)initWithDatabaseStorage:(SDSDatabaseStorage *)databaseStorage
{
    self = [super init];

    if (!self) {
        return self;
    }

    _ownIdentityKeyValueStore =
        [[SDSKeyValueStore alloc] initWithCollection:@"TSStorageManagerIdentityKeyStoreCollection"];
    _queuedVerificationStateSyncMessagesKeyValueStore =
        [[SDSKeyValueStore alloc] initWithCollection:@"OWSIdentityManager_QueuedVerificationStateSyncMessages"];

    [self observeNotifications];
//    AppReadinessRunNowOrWhenAppDidBecomeReadyAsync(^{ [self checkForPniIdentity]; });

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)observeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (ECKeyPair *)generateNewIdentityKeyForIdentity:(OWSIdentity)identity
{
    __block ECKeyPair *newKeyPair;
    
    return newKeyPair;
}

- (void)storeIdentityKeyPair:(nullable ECKeyPair *)keyPair
                 forIdentity:(OWSIdentity)identity
                 transaction:(SDSAnyWriteTransaction *)transaction
{
    [self.ownIdentityKeyValueStore setObject:keyPair key:keyForIdentity(identity) transaction:transaction];
}

- (NSString *)ensureAccountIdForAddress:(SignalServiceAddress *)address
                            transaction:(SDSAnyWriteTransaction *)transaction
{
    return @"";
}

- (nullable NSString *)accountIdForAddress:(SignalServiceAddress *)address
                               transaction:(SDSAnyReadTransaction *)transaction
{
    return @"";
}

- (nullable NSData *)identityKeyForAddress:(SignalServiceAddress *)address
{
    __block NSData *_Nullable result = nil;
    [self.databaseStorage readWithBlock:^(
        SDSAnyReadTransaction *transaction) { result = [self identityKeyForAddress:address transaction:transaction]; }];
    return result;
}

- (nullable NSData *)identityKeyForAddress:(SignalServiceAddress *)address
                               transaction:(SDSAnyReadTransaction *)transaction
{
    NSString *_Nullable accountId = [self accountIdForAddress:address transaction:transaction];
    if (accountId) {
        return [self identityKeyForAccountId:accountId transaction:transaction];
    }
    return nil;
}

- (nullable NSData *)identityKeyForAccountId:(NSString *)accountId transaction:(SDSAnyReadTransaction *)transaction
{

    return [OWSRecipientIdentity anyFetchWithUniqueId:accountId transaction:transaction].identityKey;
}

- (nullable ECKeyPair *)identityKeyPairForIdentity:(OWSIdentity)identity
{
    __block ECKeyPair *_Nullable identityKeyPair = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        identityKeyPair = [self identityKeyPairForIdentity:identity transaction:transaction];
    }];
    return identityKeyPair;
}

- (nullable ECKeyPair *)identityKeyPairForIdentity:(OWSIdentity)identity
                                       transaction:(SDSAnyReadTransaction *)transaction
{
    return nil;
}

- (int)localRegistrationIdWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    return 0;
}

- (BOOL)saveRemoteIdentity:(NSData *)identityKey address:(SignalServiceAddress *)address
{

    __block BOOL result;
    

    return result;
}

- (BOOL)saveRemoteIdentity:(NSData *)identityKey
                   address:(SignalServiceAddress *)address
               transaction:(SDSAnyWriteTransaction *)transaction
{
    NSString *accountId = [self ensureAccountIdForAddress:address transaction:transaction];
    return [self saveRemoteIdentity:identityKey accountId:accountId transaction:transaction];
}

- (BOOL)saveRemoteIdentity:(NSData *)identityKey
                 accountId:(NSString *)accountId
               transaction:(SDSAnyWriteTransaction *)transaction
{

    OWSRecipientIdentity *_Nullable existingIdentity = [OWSRecipientIdentity anyFetchWithUniqueId:accountId
                                                                                      transaction:transaction];

    if (existingIdentity == nil) {
        [[[OWSRecipientIdentity alloc] initWithAccountId:accountId
                                             identityKey:identityKey
                                         isFirstKnownKey:YES
                                               createdAt:[NSDate new]
                                       verificationState:OWSVerificationStateDefault]
            anyInsertWithTransaction:transaction];

        // Cancel any pending verification state sync messages for this recipient.
        [self clearSyncMessageForAccountId:accountId transaction:transaction];

        [self fireIdentityStateChangeNotificationAfterTransaction:transaction];

        return NO;
    }

    if (![existingIdentity.identityKey isEqual:identityKey]) {
        OWSVerificationState verificationState;
        BOOL wasIdentityVerified;
        switch (existingIdentity.verificationState) {
            case OWSVerificationStateDefault:
                verificationState = OWSVerificationStateDefault;
                wasIdentityVerified = NO;
                break;
            case OWSVerificationStateVerified:
            case OWSVerificationStateNoLongerVerified:
                verificationState = OWSVerificationStateNoLongerVerified;
                wasIdentityVerified = YES;
                break;
        }

        [self createIdentityChangeInfoMessageForAccountId:accountId
                                      wasIdentityVerified:wasIdentityVerified
                                              transaction:transaction];

        [[[OWSRecipientIdentity alloc] initWithAccountId:accountId
                                             identityKey:identityKey
                                         isFirstKnownKey:NO
                                               createdAt:[NSDate new]
                                       verificationState:verificationState] anyUpsertWithTransaction:transaction];

        // Cancel any pending verification state sync messages for this recipient.
        [self clearSyncMessageForAccountId:accountId transaction:transaction];

        [self fireIdentityStateChangeNotificationAfterTransaction:transaction];

        return YES;
    }

    return NO;
}

- (void)setVerificationState:(OWSVerificationState)verificationState
                 identityKey:(NSData *)identityKey
                     address:(SignalServiceAddress *)address
       isUserInitiatedChange:(BOOL)isUserInitiatedChange
{

}

- (void)setVerificationState:(OWSVerificationState)verificationState
                 identityKey:(NSData *)identityKey
                     address:(SignalServiceAddress *)address
       isUserInitiatedChange:(BOOL)isUserInitiatedChange
                 transaction:(SDSAnyWriteTransaction *)transaction
{

    // Ensure a remote identity exists for this key. We may be learning about
    // it for the first time.
    [self saveRemoteIdentity:identityKey address:address transaction:transaction];

    NSString *accountId = [self ensureAccountIdForAddress:address transaction:transaction];
    OWSRecipientIdentity *_Nullable recipientIdentity = [OWSRecipientIdentity anyFetchWithUniqueId:accountId
                                                                                       transaction:transaction];

    if (recipientIdentity == nil) {
        return;
    }

    if (recipientIdentity.verificationState == verificationState) {
        return;
    }

    [recipientIdentity updateWithVerificationState:verificationState transaction:transaction];

    if (isUserInitiatedChange) {
        [self saveChangeMessagesForAddress:address
                         verificationState:verificationState
                             isLocalChange:YES
                               transaction:transaction];
        [self enqueueSyncMessageForVerificationStateForAddress:address transaction:transaction];
    } else {
        // Cancel any pending verification state sync messages for this recipient.
        [self clearSyncMessageForAddress:address transaction:transaction];
    }

    [self fireIdentityStateChangeNotificationAfterTransaction:transaction];
}

- (BOOL)groupContainsUnverifiedMember:(NSString *)threadUniqueID
{
    __block BOOL result = NO;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *_Nonnull transaction) {
        result = [self groupContainsUnverifiedMember:threadUniqueID transaction:transaction];
    }];
    return result;
}

- (NSArray<SignalServiceAddress *> *)noLongerVerifiedAddressesInGroup:(NSString *)groupThreadID
                                                                limit:(NSInteger)limit
                                                          transaction:(SDSAnyReadTransaction *)transaction
{
    return [OWSRecipientIdentity noLongerVerifiedAddressesInGroup:groupThreadID limit:limit transaction:transaction];
}

- (OWSVerificationState)verificationStateForAddress:(SignalServiceAddress *)address
{
    __block OWSVerificationState result;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        result = [self verificationStateForAddress:address transaction:transaction];
    }];
    return result;
}

- (OWSVerificationState)verificationStateForAddress:(SignalServiceAddress *)address
                                        transaction:(SDSAnyReadTransaction *)transaction
{

    NSString *_Nullable accountId = [self accountIdForAddress:address transaction:transaction];
    OWSRecipientIdentity *_Nullable currentIdentity;
    if (accountId) {
        currentIdentity = [OWSRecipientIdentity anyFetchWithUniqueId:accountId transaction:transaction];
    }

    if (!currentIdentity) {
        // We might not know the identity for this recipient yet.
        return OWSVerificationStateDefault;
    }

    return currentIdentity.verificationState;
}

- (nullable OWSRecipientIdentity *)recipientIdentityForAddress:(SignalServiceAddress *)address
{

    __block OWSRecipientIdentity *_Nullable result;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        result = [self recipientIdentityForAddress:address transaction:transaction];
    }];

    return result;
}

- (nullable OWSRecipientIdentity *)recipientIdentityForAddress:(SignalServiceAddress *)address
                                                   transaction:(SDSAnyReadTransaction *)transaction
{

    NSString *_Nullable accountId = [self accountIdForAddress:address transaction:transaction];
    if (accountId) {
        return [OWSRecipientIdentity anyFetchWithUniqueId:accountId transaction:transaction];
    }
    return nil;
}

- (nullable OWSRecipientIdentity *)untrustedIdentityForSendingToAddress:(SignalServiceAddress *)address
{

    __block OWSRecipientIdentity *_Nullable result;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        result = [self untrustedIdentityForSendingToAddress:address transaction:transaction];
    }];

    return result;
}

- (nullable OWSRecipientIdentity *)untrustedIdentityForSendingToAddress:(SignalServiceAddress *)address
                                                            transaction:(SDSAnyReadTransaction *)transaction
{

    NSString *_Nullable accountId = [self accountIdForAddress:address transaction:transaction];
    OWSRecipientIdentity *_Nullable recipientIdentity;

    if (accountId) {
        recipientIdentity = [OWSRecipientIdentity anyFetchWithUniqueId:accountId transaction:transaction];
    }

    if (recipientIdentity == nil) {
        // trust on first use
        return nil;
    }

    BOOL isTrusted = [self isTrustedIdentityKey:recipientIdentity.identityKey
                                        address:address
                                      direction:TSMessageDirectionOutgoing
                                    transaction:transaction];
    if (isTrusted) {
        return nil;
    } else {
        return recipientIdentity;
    }
}

- (void)fireIdentityStateChangeNotificationAfterTransaction:(SDSAnyWriteTransaction *)transaction
{
    [transaction addAsyncCompletionOnMain:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kNSNotificationNameIdentityStateDidChange
                                                            object:nil];
    }];
}

- (BOOL)isTrustedIdentityKey:(NSData *)identityKey
                     address:(SignalServiceAddress *)address
                   direction:(TSMessageDirection)direction
                 transaction:(SDSAnyReadTransaction *)transaction
{

    if (address.isLocalAddress) {
        ECKeyPair *_Nullable localIdentityKeyPair = [self identityKeyPairForIdentity:OWSIdentityACI
                                                                         transaction:transaction];

        return NO;
    }

    switch (direction) {
        case TSMessageDirectionIncoming: {
            return YES;
        }
        case TSMessageDirectionOutgoing: {
            NSString *_Nullable accountId = [self accountIdForAddress:address transaction:transaction];
            if (!accountId) {
                return NO;
            }
            OWSRecipientIdentity *existingIdentity = [OWSRecipientIdentity anyFetchWithUniqueId:accountId
                                                                                    transaction:transaction];
            return [self isTrustedKey:identityKey forSendingToIdentity:existingIdentity];
        }
        default: {
            return NO;
        }
    }
}

- (BOOL)isTrustedKey:(NSData *)identityKey forSendingToIdentity:(nullable OWSRecipientIdentity *)recipientIdentity
{

    if (recipientIdentity == nil) {
        return YES;
    }

    if (![recipientIdentity.identityKey isEqualToData:identityKey]) {
        return NO;
    }

    if ([recipientIdentity isFirstKnownKey]) {
        return YES;
    }

    switch (recipientIdentity.verificationState) {
        case OWSVerificationStateDefault: {
            BOOL isNew = (fabs([recipientIdentity.createdAt timeIntervalSinceNow])
                < kIdentityKeyStoreNonBlockingSecondsThreshold);
            if (isNew) {
                return NO;
            } else {
                return YES;
            }
        }
        case OWSVerificationStateVerified:
            return YES;
        case OWSVerificationStateNoLongerVerified:
            return NO;
    }
}

- (void)createIdentityChangeInfoMessageForAccountId:(NSString *)accountId
                                wasIdentityVerified:(BOOL)wasIdentityVerified
                                        transaction:(SDSAnyWriteTransaction *)transaction
{
}

- (void)createIdentityChangeInfoMessageForAddress:(SignalServiceAddress *)address
                              wasIdentityVerified:(BOOL)wasIdentityVerified
                                      transaction:(SDSAnyWriteTransaction *)transaction
{

    NSMutableArray<TSMessage *> *messages = [NSMutableArray new];

    TSContactThread *contactThread = [TSContactThread getOrCreateThreadWithContactAddress:address
                                                                              transaction:transaction];
}

- (void)enqueueSyncMessageForVerificationStateForAddress:(SignalServiceAddress *)address
                                             transaction:(SDSAnyWriteTransaction *)transaction
{

    NSString *accountId = [self ensureAccountIdForAddress:address transaction:transaction];
    [self.queuedVerificationStateSyncMessagesKeyValueStore setObject:address key:accountId transaction:transaction];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self tryToSyncQueuedVerificationStates];
    });
}

- (void)tryToSyncQueuedVerificationStates
{

//    AppReadinessRunNowOrWhenMainAppDidBecomeReadyAsync(^{ [self syncQueuedVerificationStates]; });
}

- (void)syncQueuedVerificationStates
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
            [self.queuedVerificationStateSyncMessagesKeyValueStore
                enumerateKeysAndObjectsWithTransaction:transaction
                                                 block:^(NSString *key, id value, BOOL *stop) {
                                                     NSString *_Nullable accountId;
                                                     SignalServiceAddress *address;
                                                     if ([value isKindOfClass:[SignalServiceAddress class]]) {
                                                         accountId = (NSString *)key;
                                                         address = (SignalServiceAddress *)value;
                                                     } else if ([value isKindOfClass:[NSString class]]) {
                                                         // Previously, we stored phone numbers in this KV store.
                                                         NSString *phoneNumber = (NSString *)value;
                                                         address = [[SignalServiceAddress alloc]
                                                             initWithPhoneNumber:phoneNumber];
                                                         accountId =
                                                             @"";
                                                         if (accountId == nil) {
                                                             return;
                                                         }
                                                     } else {
                                                         
                                                         return;
                                                     }

                                                     OWSRecipientIdentity *recipientIdentity =
                                                         [OWSRecipientIdentity anyFetchWithUniqueId:accountId
                                                                                        transaction:transaction];
                                                     if (!recipientIdentity) {
                                                         
                                                         return;
                                                     }
                                                     if (recipientIdentity.accountId.length < 1) {
                                                         
                                                         return;
                                                     }

                                                     // Prepend key type for transit.
                                                     // TODO we should just be storing the key type so we don't have to
                                                     // juggle re-adding it.
                                                     NSData *identityKey =
                                                         [recipientIdentity.identityKey prependKeyType];
                                                     if (identityKey.length != kIdentityKeyLength) {
                                                        
                                                         return;
                                                     }
                                                     if (recipientIdentity.verificationState
                                                         == OWSVerificationStateNoLongerVerified) {
                                                         // We don't want to sync "no longer verified" state.  Other
                                                         // clients can figure this out from the /profile/ endpoint, and
                                                         // this can cause data loss as a user's devices overwrite each
                                                         // other's verification.
                                                         
                                                         return;
                                                     }
                                                 }];
        }];
    });
}

- (void)clearSyncMessageForAddress:(SignalServiceAddress *)address transaction:(SDSAnyWriteTransaction *)transaction
{

    NSString *accountId = [self ensureAccountIdForAddress:address transaction:transaction];
    [self clearSyncMessageForAccountId:accountId transaction:transaction];
}

- (void)clearSyncMessageForAccountId:(NSString *)accountId transaction:(SDSAnyWriteTransaction *)transaction
{

    [self.queuedVerificationStateSyncMessagesKeyValueStore setObject:nil key:accountId transaction:transaction];
}

- (BOOL)processIncomingVerifiedProto:(SSKProtoVerified *)verified
                         transaction:(SDSAnyWriteTransaction *)transaction
                               error:(NSError **)error
{
    return [SCKExceptionWrapper
        tryBlock:^{
            [self throws_processIncomingVerifiedProto:verified transaction:transaction];
        }
           error:error];
}

- (void)throws_processIncomingVerifiedProto:(SSKProtoVerified *)verified
                                transaction:(SDSAnyWriteTransaction *)transaction
{
}

- (void)tryToApplyVerificationStateFromSyncMessage:(OWSVerificationState)verificationState
                                           address:(SignalServiceAddress *)address
                                       identityKey:(NSData *)identityKey
                               overwriteOnConflict:(BOOL)overwriteOnConflict
                                       transaction:(SDSAnyWriteTransaction *)transaction
{

    if (!address.isValid) {
        return;
    }

    if (identityKey.length != kStoredIdentityKeyLength) {
        return;
    }

    NSString *accountId = [self ensureAccountIdForAddress:address transaction:transaction];
    OWSRecipientIdentity *_Nullable recipientIdentity = [OWSRecipientIdentity anyFetchWithUniqueId:accountId
                                                                                       transaction:transaction];
    if (!recipientIdentity) {
        // There's no existing recipient identity for this recipient.
        // We should probably create one.
        
        if (verificationState == OWSVerificationStateDefault) {
            // There's no point in creating a new recipient identity just to
            // set its verification state to default.
            return;
        }
        
        // Ensure a remote identity exists for this key. We may be learning about
        // it for the first time.
        [self saveRemoteIdentity:identityKey address:address transaction:transaction];

        recipientIdentity = [OWSRecipientIdentity anyFetchWithUniqueId:accountId transaction:transaction];

        if (recipientIdentity == nil) {
            return;
        }

        if (![recipientIdentity.accountId isEqualToString:accountId]) {
            return;
        }

        if (![recipientIdentity.identityKey isEqualToData:identityKey]) {
            return;
        }
        
        if (recipientIdentity.verificationState == verificationState) {
            return;
        }

        [recipientIdentity updateWithVerificationState:verificationState transaction:transaction];

        // No need to call [saveChangeMessagesForAddress:..] since this is
        // a new recipient.
    } else {
        // There's an existing recipient identity for this recipient.
        // We should update it.
        if (![recipientIdentity.accountId isEqualToString:accountId]) {
            return;
        }

        if (![recipientIdentity.identityKey isEqualToData:identityKey]) {
            // The conflict case where we receive a verification sync message
            // whose identity key disagrees with the local identity key for
            // this recipient.
            if (!overwriteOnConflict) {
                return;
            }
            [self saveRemoteIdentity:identityKey address:address transaction:transaction];

            recipientIdentity = [OWSRecipientIdentity anyFetchWithUniqueId:accountId transaction:transaction];

            if (recipientIdentity == nil) {
                return;
            }

            if (![recipientIdentity.accountId isEqualToString:accountId]) {
                return;
            }

            if (![recipientIdentity.identityKey isEqualToData:identityKey]) {
                return;
            }
        }
        
        if (recipientIdentity.verificationState == verificationState) {
            return;
        }

        [recipientIdentity updateWithVerificationState:verificationState transaction:transaction];

        [self saveChangeMessagesForAddress:address
                         verificationState:verificationState
                             isLocalChange:NO
                               transaction:transaction];
    }
}

// We only want to create change messages in response to user activity,
// on any of their devices.
- (void)saveChangeMessagesForAddress:(SignalServiceAddress *)address
                   verificationState:(OWSVerificationState)verificationState
                       isLocalChange:(BOOL)isLocalChange
                         transaction:(SDSAnyWriteTransaction *)transaction
{

    NSMutableArray<TSMessage *> *messages = [NSMutableArray new];

    TSContactThread *contactThread = [TSContactThread getOrCreateThreadWithContactAddress:address
                                                                              transaction:transaction];

    // MJK TODO - why not save in-line, vs storing in an array and saving the array?
    for (TSMessage *message in messages) {
        [message anyInsertWithTransaction:transaction];
    }
}

#pragma mark - Debug

#if DEBUG
- (void)clearIdentityState:(SDSAnyWriteTransaction *)transaction
{

    NSMutableArray<NSString *> *identityKeysToRemove = [NSMutableArray new];
    for (NSString *key in [self.ownIdentityKeyValueStore allKeysWithTransaction:transaction]) {
        if ([key isEqualToString:kIdentityKeyStore_ACIIdentityKey] ||
            [key isEqualToString:kIdentityKeyStore_PNIIdentityKey]) {
            // Don't delete our own keys.
            return;
        }
        [identityKeysToRemove addObject:key];
    }
    for (NSString *key in identityKeysToRemove) {
        [self.ownIdentityKeyValueStore setValue:nil forKey:key];
    }
}
#endif

#pragma mark - Notifications

- (void)applicationDidBecomeActive:(NSNotification *)notification
{

    // We want to defer this so that we never call this method until
    // [UIApplicationDelegate applicationDidBecomeActive:] is complete.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)1.f * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self tryToSyncQueuedVerificationStates];
    });
}

@end

NS_ASSUME_NONNULL_END
