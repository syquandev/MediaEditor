//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

#import "SSKEnvironment.h"
#import "AppContext.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

NSNotificationName const WarmCachesNotification = @"WarmCachesNotification";

static SSKEnvironment *sharedSSKEnvironment;

@interface SSKEnvironment ()

@property (nonatomic) id<ContactsManagerProtocol> contactsManagerRef;
@property (nonatomic) MessageSender *messageSenderRef;
@property (nonatomic) id<ProfileManagerProtocol> profileManagerRef;
@property (nonatomic) OWSMessageManager *messageManagerRef;
@property (nonatomic) BlockingManager *blockingManagerRef;
@property (nonatomic) OWSIdentityManager *identityManagerRef;
@property (nonatomic) id<OWSUDManager> udManagerRef;
@property (nonatomic) OWSMessageDecrypter *messageDecrypterRef;
@property (nonatomic) TSAccountManager *tsAccountManagerRef;
@property (nonatomic) OWS2FAManager *ows2FAManagerRef;
@property (nonatomic) OWSDisappearingMessagesJob *disappearingMessagesJobRef;
@property (nonatomic) OWSReceiptManager *receiptManagerRef;
@property (nonatomic) OWSOutgoingReceiptManager *outgoingReceiptManagerRef;
@property (nonatomic) id<SyncManagerProtocol> syncManagerRef;
@property (nonatomic) id<SSKReachabilityManager> reachabilityManagerRef;
@property (nonatomic) id<OWSTypingIndicators> typingIndicatorsRef;
@property (nonatomic) OWSAttachmentDownloads *attachmentDownloadsRef;
@property (nonatomic) SignalServiceAddressCache *signalServiceAddressCacheRef;
@property (nonatomic) SDSDatabaseStorage *databaseStorageRef;
@property (nonatomic) StorageCoordinator *storageCoordinatorRef;
@property (nonatomic) SSKPreferences *sskPreferencesRef;
@property (nonatomic) id<GroupsV2> groupsV2Ref;
@property (nonatomic) id<GroupV2Updates> groupV2UpdatesRef;
@property (nonatomic) MessageFetcherJob *messageFetcherJobRef;
@property (nonatomic) BulkProfileFetch *bulkProfileFetchRef;
@property (nonatomic) BulkUUIDLookup *bulkUUIDLookupRef;
@property (nonatomic) id<VersionedProfiles> versionedProfilesRef;
@property (nonatomic) ModelReadCaches *modelReadCachesRef;
@property (nonatomic) EarlyMessageManager *earlyMessageManagerRef;
@property (nonatomic) OWSMessagePipelineSupervisor *messagePipelineSupervisorRef;
@property (nonatomic) AppExpiry *appExpiryRef;
@property (nonatomic) id<PaymentsHelper> paymentsHelperRef;
@property (nonatomic) id<PaymentsCurrencies> paymentsCurrenciesRef;
@property (nonatomic) id<PaymentsEvents> paymentsEventsRef;
@property (nonatomic) id<MobileCoinHelper> mobileCoinHelperRef;
@property (nonatomic) SpamChallengeResolver *spamChallengeResolverRef;
@property (nonatomic) SenderKeyStore *senderKeyStoreRef;
@property (nonatomic) PhoneNumberUtil *phoneNumberUtilRef;
@property (nonatomic) id<WebSocketFactory> webSocketFactoryRef;
@property (nonatomic) ChangePhoneNumber *changePhoneNumberRef;
@property (nonatomic) id<SubscriptionManagerProtocol> subscriptionManagerRef;

@end

#pragma mark -

@implementation SSKEnvironment {
    SignalProtocolStore *_aciSignalProtocolStoreRef;
    SignalProtocolStore *_pniSignalProtocolStoreRef;
}

@synthesize callMessageHandlerRef = _callMessageHandlerRef;
@synthesize notificationsManagerRef = _notificationsManagerRef;

- (instancetype)initWithContactsManager:(id<ContactsManagerProtocol>)contactsManager
                     linkPreviewManager:(OWSLinkPreviewManager *)linkPreviewManager
                    remoteConfigManager:(id<RemoteConfigManager>)remoteConfigManager
                 aciSignalProtocolStore:(SignalProtocolStore *)aciSignalProtocolStore
                 pniSignalProtocolStore:(SignalProtocolStore *)pniSignalProtocolStore
                              udManager:(id<OWSUDManager>)udManager
                          ows2FAManager:(OWS2FAManager *)ows2FAManager
                       typingIndicators:(id<OWSTypingIndicators>)typingIndicators
                    attachmentDownloads:(OWSAttachmentDownloads *)attachmentDownloads
              signalServiceAddressCache:(SignalServiceAddressCache *)signalServiceAddressCache
                         sskPreferences:(SSKPreferences *)sskPreferences
                       bulkProfileFetch:(BulkProfileFetch *)bulkProfileFetch
                         bulkUUIDLookup:(BulkUUIDLookup *)bulkUUIDLookup
                        modelReadCaches:(ModelReadCaches *)modelReadCaches
                              appExpiry:(AppExpiry *)appExpiry
                         senderKeyStore:(SenderKeyStore *)senderKeyStore
                      changePhoneNumber:(ChangePhoneNumber *)changePhoneNumber
{
    self = [super init];
    if (!self) {
        return self;
    }
    
    _contactsManagerRef = contactsManager;
    _linkPreviewManagerRef = linkPreviewManager;
    _remoteConfigManagerRef = remoteConfigManager;
    _aciSignalProtocolStoreRef = aciSignalProtocolStore;
    _pniSignalProtocolStoreRef = pniSignalProtocolStore;
    _udManagerRef = udManager;
    _ows2FAManagerRef = ows2FAManager;
    _typingIndicatorsRef = typingIndicators;
    _attachmentDownloadsRef = attachmentDownloads;
    _signalServiceAddressCacheRef = signalServiceAddressCache;
    _sskPreferencesRef = sskPreferences;
    _bulkUUIDLookupRef = bulkUUIDLookup;
    _modelReadCachesRef = modelReadCaches;
    _appExpiryRef = appExpiry;
    _senderKeyStoreRef = senderKeyStore;
    _changePhoneNumberRef = changePhoneNumber;

    return self;
}

+ (instancetype)shared
{
    
    return sharedSSKEnvironment;
}

+ (void)setShared:(SSKEnvironment *)env
{
    
    sharedSSKEnvironment = env;
}

+ (void)clearSharedForTests
{
    sharedSSKEnvironment = nil;
}

+ (BOOL)hasShared
{
    return sharedSSKEnvironment != nil;
}

#pragma mark - Mutable Accessors

- (nullable id<OWSCallMessageHandler>)callMessageHandlerRef
{
    @synchronized(self) {
        
        return _callMessageHandlerRef;
    }
}

- (void)setCallMessageHandlerRef:(nullable id<OWSCallMessageHandler>)callMessageHandlerRef
{
    @synchronized(self) {
        
        _callMessageHandlerRef = callMessageHandlerRef;
    }
}

- (nullable id<NotificationsProtocol>)notificationsManagerRef
{
    @synchronized(self) {
        
        return _notificationsManagerRef;
    }
}

- (void)setNotificationsManagerRef:(nullable id<NotificationsProtocol>)notificationsManagerRef
{
    @synchronized(self) {
        
        _notificationsManagerRef = notificationsManagerRef;
    }
}

- (SignalProtocolStore *)signalProtocolStoreRefForIdentity:(OWSIdentity)identity
{
    switch (identity) {
        case OWSIdentityACI:
            return _aciSignalProtocolStoreRef;
        case OWSIdentityPNI:
            return _pniSignalProtocolStoreRef;
    }
}

- (BOOL)isComplete
{
    return true;
//    return (self.callMessageHandler != nil && self.notificationsManager != nil);
}

- (void)warmCaches
{
    NSArray *specs = @[
//        @"signalServiceAddressCache",
//        ^{ [self.signalServiceAddressCache warmCaches]; },
        @"remoteConfigManager",
        ^{ [self.remoteConfigManager warmCaches]; },
        @"udManager",
        ^{ [self.udManager warmCaches]; },
        @"PinnedThreadManager",
        ^{ [PinnedThreadManager warmCaches]; },
        @"typingIndicatorsImpl",
        ^{ [self.typingIndicatorsImpl warmCaches]; }
    ];

    for (int i = 0; i < specs.count / 2; i++) {
        [InstrumentsMonitor measureWithCategory:@"appstart"
                                         parent:@"caches"
                                           name:[specs objectAtIndex:2 * i]
                                          block:[specs objectAtIndex:2 * i + 1]];
    }
    [NSNotificationCenter.defaultCenter postNotificationName:WarmCachesNotification object:nil];
}

@end

NS_ASSUME_NONNULL_END
