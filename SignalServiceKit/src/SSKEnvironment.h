//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const WarmCachesNotification;

@class AccountServiceClient;
@class AppExpiry;
@class BlockingManager;
@class BulkProfileFetch;
@class BulkUUIDLookup;
@class ChangePhoneNumber;
@class EarlyMessageManager;
@class GroupsV2MessageProcessor;
@class MessageFetcherJob;
@class MessageProcessor;
@class MessageSender;
@class MessageSenderJobQueue;
@class ModelReadCaches;
@class NetworkManager;
@class OWS2FAManager;
@class OWSAttachmentDownloads;
@class OWSDisappearingMessagesJob;
@class OWSIdentityManager;
@class OWSLinkPreviewManager;
@class OWSMessageDecrypter;
@class OWSMessageManager;
@class OWSMessagePipelineSupervisor;
@class OWSOutgoingReceiptManager;
@class OWSReceiptManager;
@class PhoneNumberUtil;
@class SDSDatabaseStorage;
@class SSKPreferences;
@class SenderKeyStore;
@class SignalProtocolStore;
@class SignalServiceAddressCache;
@class SocketManager;
@class SpamChallengeResolver;
@class StorageCoordinator;
@class TSAccountManager;

@protocol ContactsManagerProtocol;
@protocol GroupV2Updates;
@protocol GroupsV2;
@protocol MobileCoinHelper;
@protocol NotificationsProtocol;
@protocol OWSCallMessageHandler;
@protocol OWSTypingIndicators;
@protocol OWSUDManager;
@protocol PaymentsCurrencies;
@protocol PaymentsEvents;
@protocol PaymentsHelper;
@protocol PendingReceiptRecorder;
@protocol ProfileManagerProtocol;
@protocol RemoteConfigManager;
@protocol SSKReachabilityManager;
@protocol StorageServiceManagerProtocol;
@protocol SubscriptionManagerProtocol;
@protocol SyncManagerProtocol;
@protocol VersionedProfiles;
@protocol WebSocketFactory;

typedef NS_ENUM(uint8_t, OWSIdentity);

@interface SSKEnvironment : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

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
                      changePhoneNumber:(ChangePhoneNumber *)changePhoneNumber NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly, class) SSKEnvironment *shared;

+ (void)setShared:(SSKEnvironment *)env;

#ifdef TESTABLE_BUILD
// Should only be called by tests.
+ (void)clearSharedForTests;
#endif

+ (BOOL)hasShared;

@property (nonatomic, readonly) id<ContactsManagerProtocol> contactsManagerRef;
@property (nonatomic, readonly) OWSLinkPreviewManager *linkPreviewManagerRef;
@property (nonatomic, readonly) MessageSender *messageSenderRef;
@property (nonatomic, readonly) MessageSenderJobQueue *messageSenderJobQueueRef;
@property (nonatomic, readonly) id<PendingReceiptRecorder> pendingReceiptRecorderRef;
@property (nonatomic, readonly) id<ProfileManagerProtocol> profileManagerRef;
@property (nonatomic, readonly) NetworkManager *networkManagerRef;
@property (nonatomic, readonly) OWSMessageManager *messageManagerRef;
@property (nonatomic, readonly) BlockingManager *blockingManagerRef;
@property (nonatomic, readonly) OWSIdentityManager *identityManagerRef;
@property (nonatomic, readonly) id<RemoteConfigManager> remoteConfigManagerRef;
@property (nonatomic, readonly) id<OWSUDManager> udManagerRef;
@property (nonatomic, readonly) OWSMessageDecrypter *messageDecrypterRef;
@property (nonatomic, readonly) GroupsV2MessageProcessor *groupsV2MessageProcessorRef;
@property (nonatomic, readonly) SocketManager *socketManagerRef;
@property (nonatomic, readonly) TSAccountManager *tsAccountManagerRef;
@property (nonatomic, readonly) OWS2FAManager *ows2FAManagerRef;
@property (nonatomic, readonly) OWSDisappearingMessagesJob *disappearingMessagesJobRef;
@property (nonatomic, readonly) OWSReceiptManager *receiptManagerRef;
@property (nonatomic, readonly) OWSOutgoingReceiptManager *outgoingReceiptManagerRef;
@property (nonatomic, readonly) id<SyncManagerProtocol> syncManagerRef;
@property (nonatomic, readonly) id<SSKReachabilityManager> reachabilityManagerRef;
@property (nonatomic, readonly) id<OWSTypingIndicators> typingIndicatorsRef;
@property (nonatomic, readonly) OWSAttachmentDownloads *attachmentDownloadsRef;
@property (nonatomic, readonly) SignalServiceAddressCache *signalServiceAddressCacheRef;
@property (nonatomic, readonly) AccountServiceClient *accountServiceClientRef;
@property (nonatomic, readonly) id<StorageServiceManagerProtocol> storageServiceManagerRef;
@property (nonatomic, readonly) id<GroupsV2> groupsV2Ref;
@property (nonatomic, readonly) id<GroupV2Updates> groupV2UpdatesRef;
@property (nonatomic, readonly) SDSDatabaseStorage *databaseStorageRef;
@property (nonatomic, readonly) StorageCoordinator *storageCoordinatorRef;
@property (nonatomic, readonly) SSKPreferences *sskPreferencesRef;
@property (nonatomic, readonly) MessageFetcherJob *messageFetcherJobRef;
@property (nonatomic, readonly) BulkProfileFetch *bulkProfileFetchRef;
@property (nonatomic, readonly) BulkUUIDLookup *bulkUUIDLookupRef;
@property (nonatomic, readonly) id<VersionedProfiles> versionedProfilesRef;
@property (nonatomic, readonly) ModelReadCaches *modelReadCachesRef;
@property (nonatomic, readonly) EarlyMessageManager *earlyMessageManagerRef;
@property (nonatomic, readonly) OWSMessagePipelineSupervisor *messagePipelineSupervisorRef;
@property (nonatomic, readonly) AppExpiry *appExpiryRef;
@property (nonatomic, readonly) MessageProcessor *messageProcessorRef;
@property (nonatomic, readonly) id<PaymentsHelper> paymentsHelperRef;
@property (nonatomic, readonly) id<PaymentsCurrencies> paymentsCurrenciesRef;
@property (nonatomic, readonly) id<PaymentsEvents> paymentsEventsRef;
@property (nonatomic, readonly) id<MobileCoinHelper> mobileCoinHelperRef;
@property (nonatomic, readonly) SpamChallengeResolver *spamChallengeResolverRef;
@property (nonatomic, readonly) SenderKeyStore *senderKeyStoreRef;
@property (nonatomic, readonly) PhoneNumberUtil *phoneNumberUtilRef;
@property (nonatomic, readonly) id<WebSocketFactory> webSocketFactoryRef;
@property (nonatomic, readonly) ChangePhoneNumber *changePhoneNumberRef;
@property (nonatomic, readonly) id<SubscriptionManagerProtocol> subscriptionManagerRef;

// This property is configured after Environment is created.
@property (atomic, nullable) id<OWSCallMessageHandler> callMessageHandlerRef;
// This property is configured after Environment is created.
@property (atomic, nullable) id<NotificationsProtocol> notificationsManagerRef;

- (SignalProtocolStore *)signalProtocolStoreRefForIdentity:(OWSIdentity)identity;

- (BOOL)isComplete;

- (void)warmCaches;

@end

NS_ASSUME_NONNULL_END
