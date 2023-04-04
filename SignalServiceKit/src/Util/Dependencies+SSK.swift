//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation

// Exposes singleton accessors.
//
// Swift classes which do not subclass NSObject can implement Dependencies protocol.

public protocol Dependencies {}

// MARK: - NSObject

@objc
public extension NSObject {
    final var attachmentDownloads: OWSAttachmentDownloads {
        SSKEnvironment.shared.attachmentDownloadsRef
    }

    static var attachmentDownloads: OWSAttachmentDownloads {
        SSKEnvironment.shared.attachmentDownloadsRef
    }

    final var bulkProfileFetch: BulkProfileFetch {
        SSKEnvironment.shared.bulkProfileFetchRef
    }

    static var bulkProfileFetch: BulkProfileFetch {
        SSKEnvironment.shared.bulkProfileFetchRef
    }

    final var databaseStorage: SDSDatabaseStorage {
        SDSDatabaseStorage.shared
    }

    static var databaseStorage: SDSDatabaseStorage {
        SDSDatabaseStorage.shared
    }

    final var identityManager: OWSIdentityManager {
        SSKEnvironment.shared.identityManagerRef
    }

    static var identityManager: OWSIdentityManager {
        SSKEnvironment.shared.identityManagerRef
    }

    final var ows2FAManager: OWS2FAManager {
        .shared
    }

    static var ows2FAManager: OWS2FAManager {
        .shared
    }

    final var storageCoordinator: StorageCoordinator {
        SSKEnvironment.shared.storageCoordinatorRef
    }

    static var storageCoordinator: StorageCoordinator {
        SSKEnvironment.shared.storageCoordinatorRef
    }

    final var syncManager: SyncManagerProtocol {
        SSKEnvironment.shared.syncManagerRef
    }

    static var syncManager: SyncManagerProtocol {
        SSKEnvironment.shared.syncManagerRef
    }

    final var typingIndicatorsImpl: TypingIndicators {
        SSKEnvironment.shared.typingIndicatorsRef
    }

    static var typingIndicatorsImpl: TypingIndicators {
        SSKEnvironment.shared.typingIndicatorsRef
    }

    final var udManager: OWSUDManager {
        SSKEnvironment.shared.udManagerRef
    }

    static var udManager: OWSUDManager {
        SSKEnvironment.shared.udManagerRef
    }

    final var storageServiceManager: StorageServiceManagerProtocol {
        SSKEnvironment.shared.storageServiceManagerRef
    }

    static var storageServiceManager: StorageServiceManagerProtocol {
        SSKEnvironment.shared.storageServiceManagerRef
    }

    final var modelReadCaches: ModelReadCaches {
        SSKEnvironment.shared.modelReadCachesRef
    }

    static var modelReadCaches: ModelReadCaches {
        SSKEnvironment.shared.modelReadCachesRef
    }

    final var remoteConfigManager: RemoteConfigManager {
        SSKEnvironment.shared.remoteConfigManagerRef
    }

    static var remoteConfigManager: RemoteConfigManager {
        SSKEnvironment.shared.remoteConfigManagerRef
    }

    final var appExpiry: AppExpiry {
        SSKEnvironment.shared.appExpiryRef
    }

    static var appExpiry: AppExpiry {
        SSKEnvironment.shared.appExpiryRef
    }

    final var signalService: OWSSignalService {
        .shared()
    }

    static var signalService: OWSSignalService {
        .shared()
    }

    final var grdbStorageAdapter: GRDBDatabaseStorageAdapter {
        databaseStorage.grdbStorage
    }

    static var grdbStorageAdapter: GRDBDatabaseStorageAdapter {
        databaseStorage.grdbStorage
    }

    final var signalServiceAddressCache: SignalServiceAddressCache {
        SSKEnvironment.shared.signalServiceAddressCacheRef
    }

    static var signalServiceAddressCache: SignalServiceAddressCache {
        SSKEnvironment.shared.signalServiceAddressCacheRef
    }

    final var deviceManager: OWSDeviceManager {
        .shared()
    }

    static var deviceManager: OWSDeviceManager {
        .shared()
    }

    final var bulkUUIDLookup: BulkUUIDLookup {
        SSKEnvironment.shared.bulkUUIDLookupRef
    }

    static var bulkUUIDLookup: BulkUUIDLookup {
        SSKEnvironment.shared.bulkUUIDLookupRef
    }

    final var senderKeyStore: SenderKeyStore {
        SSKEnvironment.shared.senderKeyStoreRef
    }

    static var senderKeyStore: SenderKeyStore {
        SSKEnvironment.shared.senderKeyStoreRef
    }

    final var appVersion: AppVersion {
        AppVersion.shared()
    }

    static var appVersion: AppVersion {
        AppVersion.shared()
    }

    var changePhoneNumber: ChangePhoneNumber {
        SSKEnvironment.shared.changePhoneNumberRef
    }

    static var changePhoneNumber: ChangePhoneNumber {
        SSKEnvironment.shared.changePhoneNumberRef
    }

    var subscriptionManager: SubscriptionManagerProtocol {
        SSKEnvironment.shared.subscriptionManagerRef
    }

    static var subscriptionManager: SubscriptionManagerProtocol {
        SSKEnvironment.shared.subscriptionManagerRef
    }
}

// MARK: - Obj-C Dependencies

public extension Dependencies {

    var attachmentDownloads: OWSAttachmentDownloads {
        SSKEnvironment.shared.attachmentDownloadsRef
    }

    static var attachmentDownloads: OWSAttachmentDownloads {
        SSKEnvironment.shared.attachmentDownloadsRef
    }

    var bulkProfileFetch: BulkProfileFetch {
        SSKEnvironment.shared.bulkProfileFetchRef
    }

    static var bulkProfileFetch: BulkProfileFetch {
        SSKEnvironment.shared.bulkProfileFetchRef
    }

    var databaseStorage: SDSDatabaseStorage {
        SDSDatabaseStorage.shared
    }

    static var databaseStorage: SDSDatabaseStorage {
        SDSDatabaseStorage.shared
    }

    var identityManager: OWSIdentityManager {
        SSKEnvironment.shared.identityManagerRef
    }

    static var identityManager: OWSIdentityManager {
        SSKEnvironment.shared.identityManagerRef
    }

    var linkPreviewManager: OWSLinkPreviewManager {
        SSKEnvironment.shared.linkPreviewManagerRef
    }

    static var linkPreviewManager: OWSLinkPreviewManager {
        SSKEnvironment.shared.linkPreviewManagerRef
    }

    var ows2FAManager: OWS2FAManager {
        .shared
    }

    static var ows2FAManager: OWS2FAManager {
        .shared
    }

    var storageCoordinator: StorageCoordinator {
        SSKEnvironment.shared.storageCoordinatorRef
    }

    static var storageCoordinator: StorageCoordinator {
        SSKEnvironment.shared.storageCoordinatorRef
    }

    var syncManager: SyncManagerProtocol {
        SSKEnvironment.shared.syncManagerRef
    }

    static var syncManager: SyncManagerProtocol {
        SSKEnvironment.shared.syncManagerRef
    }

    var typingIndicatorsImpl: TypingIndicators {
        SSKEnvironment.shared.typingIndicatorsRef
    }

    static var typingIndicatorsImpl: TypingIndicators {
        SSKEnvironment.shared.typingIndicatorsRef
    }

    var udManager: OWSUDManager {
        SSKEnvironment.shared.udManagerRef
    }

    static var udManager: OWSUDManager {
        SSKEnvironment.shared.udManagerRef
    }

    var storageServiceManager: StorageServiceManagerProtocol {
        SSKEnvironment.shared.storageServiceManagerRef
    }

    static var storageServiceManager: StorageServiceManagerProtocol {
        SSKEnvironment.shared.storageServiceManagerRef
    }

    var modelReadCaches: ModelReadCaches {
        SSKEnvironment.shared.modelReadCachesRef
    }

    static var modelReadCaches: ModelReadCaches {
        SSKEnvironment.shared.modelReadCachesRef
    }

    var remoteConfigManager: RemoteConfigManager {
        SSKEnvironment.shared.remoteConfigManagerRef
    }

    static var remoteConfigManager: RemoteConfigManager {
        SSKEnvironment.shared.remoteConfigManagerRef
    }

    var appExpiry: AppExpiry {
        SSKEnvironment.shared.appExpiryRef
    }

    static var appExpiry: AppExpiry {
        SSKEnvironment.shared.appExpiryRef
    }

    var signalService: OWSSignalService {
        .shared()
    }

    static var signalService: OWSSignalService {
        .shared()
    }

    var signalServiceAddressCache: SignalServiceAddressCache {
        SSKEnvironment.shared.signalServiceAddressCacheRef
    }

    static var signalServiceAddressCache: SignalServiceAddressCache {
        SSKEnvironment.shared.signalServiceAddressCacheRef
    }

    var deviceManager: OWSDeviceManager {
        .shared()
    }

    static var deviceManager: OWSDeviceManager {
        .shared()
    }

    var bulkUUIDLookup: BulkUUIDLookup {
        SSKEnvironment.shared.bulkUUIDLookupRef
    }

    static var bulkUUIDLookup: BulkUUIDLookup {
        SSKEnvironment.shared.bulkUUIDLookupRef
    }

    var senderKeyStore: SenderKeyStore {
        SSKEnvironment.shared.senderKeyStoreRef
    }

    static var senderKeyStore: SenderKeyStore {
        SSKEnvironment.shared.senderKeyStoreRef
    }

    var appVersion: AppVersion {
        AppVersion.shared()
    }

    static var appVersion: AppVersion {
        AppVersion.shared()
    }

    var changePhoneNumber: ChangePhoneNumber {
        SSKEnvironment.shared.changePhoneNumberRef
    }

    static var changePhoneNumber: ChangePhoneNumber {
        SSKEnvironment.shared.changePhoneNumberRef
    }

    var subscriptionManager: SubscriptionManagerProtocol {
        SSKEnvironment.shared.subscriptionManagerRef
    }

    static var subscriptionManager: SubscriptionManagerProtocol {
        SSKEnvironment.shared.subscriptionManagerRef
    }
}

// MARK: -

@objc
public extension SDSDatabaseStorage {
    static var shared: SDSDatabaseStorage {
        SSKEnvironment.shared.databaseStorageRef
    }
}

// MARK: -

@objc
public extension OWS2FAManager {
    static var shared: OWS2FAManager {
        SSKEnvironment.shared.ows2FAManagerRef
    }
}


// MARK: -

@objc
public extension ModelReadCaches {
    static var shared: ModelReadCaches {
        SSKEnvironment.shared.modelReadCachesRef
    }
}

@objc
public extension SSKPreferences {
    static var shared: SSKPreferences {
        SSKEnvironment.shared.sskPreferencesRef
    }
}

// MARK: -

@objc
public extension OWSIdentityManager {
    static var shared: OWSIdentityManager {
        SSKEnvironment.shared.identityManagerRef
    }
}
