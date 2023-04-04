//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalCoreKit
import UIKit

public enum OWSUDError: Error {
    case assertionError(description: String)
    case invalidData(description: String)
}

// MARK: -

extension OWSUDError: IsRetryableProvider {
    public var isRetryableProvider: Bool {
        switch self {
        case .assertionError, .invalidData:
            return false
        }
    }
}

// MARK: -

@objc
public enum OWSUDCertificateExpirationPolicy: Int {
    // We want to try to rotate the sender certificate
    // on a frequent basis, but we don't want to block
    // sending on this.
    case strict
    case permissive
}

// MARK: -

@objc
public enum UnidentifiedAccessMode: Int {
    case unknown
    case enabled
    case disabled
    case unrestricted
}

// MARK: -

extension UnidentifiedAccessMode: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown:
            return "unknown"
        case .enabled:
            return "enabled"
        case .disabled:
            return "disabled"
        case .unrestricted:
            return "unrestricted"
        }
    }
}

// MARK: -

@objc
public class OWSUDAccess: NSObject {
    @objc
    public let udAccessKey: SMKUDAccessKey
    public var senderKeyUDAccessKey: SMKUDAccessKey {
        // If unrestricted, we use a zeroed out key instead of a random key
        // This ensures we don't scribble over the rest of our composite key when talking to the multi_recipient endpoint
        udAccessMode == .unrestricted ? .zeroedKey : udAccessKey
    }

    @objc
    public let udAccessMode: UnidentifiedAccessMode

    @objc
    public let isRandomKey: Bool

    @objc
    public required init(udAccessKey: SMKUDAccessKey,
                         udAccessMode: UnidentifiedAccessMode,
                         isRandomKey: Bool) {
        self.udAccessKey = udAccessKey
        self.udAccessMode = udAccessMode
        self.isRandomKey = isRandomKey
    }
}

// MARK: -

@objc
public class OWSUDSendingAccess: NSObject {

    @objc
    public let udAccess: OWSUDAccess


    init(udAccess: OWSUDAccess) {
        self.udAccess = udAccess
    }
}

// MARK: -

@objc public protocol OWSUDManager: AnyObject {
    @objc
    var keyValueStore: SDSKeyValueStore { get }
    @objc
    var phoneNumberAccessStore: SDSKeyValueStore { get }
    @objc
    var uuidAccessStore: SDSKeyValueStore { get }

    @objc func warmCaches()

    @objc func isUDVerboseLoggingEnabled() -> Bool

    // MARK: - Recipient State

    @objc
    func setUnidentifiedAccessMode(_ mode: UnidentifiedAccessMode, address: SignalServiceAddress)

    @objc
    func udAccessKey(forAddress address: SignalServiceAddress) -> SMKUDAccessKey?

    @objc
    func udAccess(forAddress address: SignalServiceAddress, requireSyncAccess: Bool) -> OWSUDAccess?

    @objc
    func removeSenderCertificates(transaction: SDSAnyWriteTransaction)

    // MARK: Unrestricted Access

    @objc
    func shouldAllowUnrestrictedAccessLocal() -> Bool
    @objc
    func setShouldAllowUnrestrictedAccessLocal(_ value: Bool)

    var phoneNumberSharingMode: PhoneNumberSharingMode { get }

    func setPhoneNumberSharingMode(
        _ mode: PhoneNumberSharingMode,
        updateStorageService: Bool,
        transaction: GRDBWriteTransaction
    )
}

// MARK: -

@objc
public class OWSUDManagerImpl: NSObject, OWSUDManager {

    @objc
    public let keyValueStore = SDSKeyValueStore(collection: "kUDCollection")
    @objc
    public let phoneNumberAccessStore = SDSKeyValueStore(collection: "kUnidentifiedAccessCollection")
    @objc
    public let uuidAccessStore = SDSKeyValueStore(collection: "kUnidentifiedAccessUUIDCollection")

    // MARK: Local Configuration State

    private let kUDCurrentSenderCertificateKey_Production = "kUDCurrentSenderCertificateKey_Production-uuid"
    private let kUDCurrentSenderCertificateKey_Staging = "kUDCurrentSenderCertificateKey_Staging-uuid"
    private let kUDCurrentSenderCertificateDateKey_Production = "kUDCurrentSenderCertificateDateKey_Production-uuid"
    private let kUDCurrentSenderCertificateDateKey_Staging = "kUDCurrentSenderCertificateDateKey_Staging-uuid"
    private let kUDUnrestrictedAccessKey = "kUDUnrestrictedAccessKey"

    // To avoid deadlock, never open a database transaction while
    // unfairLock is acquired.
    private let unfairLock = UnfairLock()

    // These two caches should only be accessed using unfairLock.
    //
    // TODO: We might not want to use comprehensive caches here.
    private var phoneNumberAccessCache = [String: UnidentifiedAccessMode]()
    private var uuidAccessCache = [UUID: UnidentifiedAccessMode]()

    @objc
    public required override init() {

        super.init()

        SwiftSingletons.register(self)

        AppReadiness.runNowOrWhenAppDidBecomeReadySync {
            self.setup()
        }
    }

    @objc
    public func warmCaches() {
        owsAssertDebug(GRDBSchemaMigrator.areMigrationsComplete)

        let parseUnidentifiedAccessMode = { (anyValue: Any) -> UnidentifiedAccessMode? in
            guard let nsNumber = anyValue as? NSNumber else {
                owsFailDebug("Invalid value.")
                return nil
            }
            guard let value = UnidentifiedAccessMode(rawValue: nsNumber.intValue) else {
                owsFailDebug("Couldn't parse mode value: (nsNumber.intValue).")
                return nil
            }
            return value
        }

        databaseStorage.read { transaction in
            self.cachePhoneNumberSharingMode(transaction: transaction.unwrapGrdbRead)

            self.unfairLock.withLock {
                self.phoneNumberAccessStore.enumerateKeysAndObjects(transaction: transaction) { (phoneNumber: String, anyValue: Any, _) in
                    guard let mode = parseUnidentifiedAccessMode(anyValue) else {
                        return
                    }
                    self.phoneNumberAccessCache[phoneNumber] = mode
                }
                self.uuidAccessStore.enumerateKeysAndObjects(transaction: transaction) { (uuidString: String, anyValue: Any, _) in
                    guard let uuid = UUID(uuidString: uuidString) else {
                        owsFailDebug("Invalid uuid: \(uuidString)")
                        return
                    }
                    guard let mode = parseUnidentifiedAccessMode(anyValue) else {
                        return
                    }
                    self.uuidAccessCache[uuid] = mode
                }

                if DebugFlags.internalLogging {
                    Logger.info("phoneNumberAccessCache: \(phoneNumberAccessCache.count), uuidAccessCache: \(uuidAccessCache.count), ")
                }
            }
        }
    }

    private func setup() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didBecomeActive),
                                               name: .OWSApplicationDidBecomeActive,
                                               object: nil)
    }

    @objc
    func registrationStateDidChange() {
        AssertIsOnMainThread()
        owsAssertDebug(AppReadiness.isAppReady)
    }

    @objc
    func didBecomeActive() {
        AssertIsOnMainThread()
        owsAssertDebug(AppReadiness.isAppReady)
    }

    // MARK: -

    @objc
    public func isUDVerboseLoggingEnabled() -> Bool {
        return false
    }

    // MARK: - Recipient state

    @objc
    public func randomUDAccessKey() -> SMKUDAccessKey {
        return SMKUDAccessKey(randomKeyData: ())
    }

    private func unidentifiedAccessMode(forAddress address: SignalServiceAddress) -> UnidentifiedAccessMode {

        // Read from caches.
        var existingUUIDValue: UnidentifiedAccessMode?
        var existingPhoneNumberValue: UnidentifiedAccessMode?
        unfairLock.withLock {
            if let uuid = address.uuid {
                existingUUIDValue = self.uuidAccessCache[uuid]
            }
            if let phoneNumber = address.phoneNumber {
                existingPhoneNumberValue = self.phoneNumberAccessCache[phoneNumber]
            }
        }

        // Resolve current value; determine if we need to update cache and database.
        let existingValue: UnidentifiedAccessMode?
        var shouldUpdateValues = false
        if let existingUUIDValue = existingUUIDValue, let existingPhoneNumberValue = existingPhoneNumberValue {

            // If UUID and Phone Number setting don't align, defer to UUID and update phone number
            if existingPhoneNumberValue != existingUUIDValue {
                Logger.warn("Unexpected UD value mismatch; updating UD state.")
                shouldUpdateValues = true
                existingValue = .disabled

                // Fetch profile for this user to determine current UD state.
                self.bulkProfileFetch.fetchProfile(address: address)
            } else {
                existingValue = existingUUIDValue
            }
        } else if let existingPhoneNumberValue = existingPhoneNumberValue {
            existingValue = existingPhoneNumberValue

            // We had phone number entry but not UUID, update UUID value
            if nil != address.uuidString {
                shouldUpdateValues = true
            }
        } else if let existingUUIDValue = existingUUIDValue {
            existingValue = existingUUIDValue

            // We had UUID entry but not phone number, update phone number value
            if nil != address.phoneNumber {
                shouldUpdateValues = true
            }
        } else {
            existingValue = nil
        }

        if let existingValue = existingValue, shouldUpdateValues {
            setUnidentifiedAccessMode(existingValue, address: address)
        }

        let defaultValue: UnidentifiedAccessMode =  address.isLocalAddress ? .enabled : .unknown
        return existingValue ?? defaultValue
    }

    @objc
    public func setUnidentifiedAccessMode(_ mode: UnidentifiedAccessMode, address: SignalServiceAddress) {
        if address.isLocalAddress {
            Logger.info("Setting local UD access mode: \(mode)")
        }

        // Update cache immediately.
        var didChange = false
        self.unfairLock.withLock {
            if let uuid = address.uuid {
                if self.uuidAccessCache[uuid] != mode {
                    didChange = true
                }
                self.uuidAccessCache[uuid] = mode
            }
            if let phoneNumber = address.phoneNumber {
                if self.phoneNumberAccessCache[phoneNumber] != mode {
                    didChange = true
                }
                self.phoneNumberAccessCache[phoneNumber] = mode
            }
        }
        guard didChange else {
            return
        }
        // Update database async.
        databaseStorage.asyncWrite { transaction in
            if let uuid = address.uuid {
                self.uuidAccessStore.setInt(mode.rawValue, key: uuid.uuidString, transaction: transaction)
            }
            if let phoneNumber = address.phoneNumber {
                self.phoneNumberAccessStore.setInt(mode.rawValue, key: phoneNumber, transaction: transaction)
            }
        }
    }

    // Returns the UD access key for a given recipient
    // if we have a valid profile key for them.
    @objc
    public func udAccessKey(forAddress address: SignalServiceAddress) -> SMKUDAccessKey? {
        return nil
    }

    // Returns the UD access key for sending to a given recipient or fetching a profile
    @objc
    public func udAccess(forAddress address: SignalServiceAddress, requireSyncAccess: Bool) -> OWSUDAccess? {
        if requireSyncAccess {
            if address.isLocalAddress {
                let selfAccessMode = unidentifiedAccessMode(forAddress: address)
                guard selfAccessMode != .disabled else {
                    if isUDVerboseLoggingEnabled() {
                        Logger.info("UD disabled for \(address), UD disabled for sync messages.")
                    }
                    return nil
                }
            }
        }

        let accessMode = unidentifiedAccessMode(forAddress: address)

        switch accessMode {
        case .unrestricted:
            // Unrestricted users should use a random key.
            if isUDVerboseLoggingEnabled() {
                Logger.info("UD enabled for \(address) with random key.")
            }
            let udAccessKey = randomUDAccessKey()
            return OWSUDAccess(udAccessKey: udAccessKey, udAccessMode: accessMode, isRandomKey: true)
        case .unknown:
            // Unknown users should use a derived key if possible,
            // and otherwise use a random key.
            if let udAccessKey = udAccessKey(forAddress: address) {
                if isUDVerboseLoggingEnabled() {
                    Logger.info("UD unknown for \(address); trying derived key.")
                }
                return OWSUDAccess(udAccessKey: udAccessKey, udAccessMode: accessMode, isRandomKey: false)
            } else {
                if isUDVerboseLoggingEnabled() {
                    Logger.info("UD unknown for \(address); trying random key.")
                }
                let udAccessKey = randomUDAccessKey()
                return OWSUDAccess(udAccessKey: udAccessKey, udAccessMode: accessMode, isRandomKey: true)
            }
        case .enabled:
            guard let udAccessKey = udAccessKey(forAddress: address) else {
                if isUDVerboseLoggingEnabled() {
                    Logger.info("UD disabled for \(address), no profile key for this recipient.")
                }
                // Not an error.
                // We can only use UD if the user has UD enabled _and_
                // we know their profile key.
                Logger.warn("Missing profile key for UD-enabled user: \(address).")
                return nil
            }
            if isUDVerboseLoggingEnabled() {
                Logger.info("UD enabled for \(address).")
            }
            return OWSUDAccess(udAccessKey: udAccessKey, udAccessMode: accessMode, isRandomKey: false)
        case .disabled:
            if isUDVerboseLoggingEnabled() {
                Logger.info("UD disabled for \(address), UD not enabled for this recipient.")
            }
            return nil
        }
    }

    // Returns the UD access key and appropriate sender certificate for sending to a given recipient
    @objc
    public func udSendingAccess(forAddress address: SignalServiceAddress,
                                requireSyncAccess: Bool) -> OWSUDSendingAccess? {
        guard let udAccess = self.udAccess(forAddress: address, requireSyncAccess: requireSyncAccess) else {
            return nil
        }

        return OWSUDSendingAccess(udAccess: udAccess)
    }

    // MARK: - Sender Certificate

    #if TESTABLE_BUILD
    @objc
    public func hasSenderCertificates() -> Bool {
        return senderCertificate(uuidOnly: true, certificateExpirationPolicy: .permissive) != nil
            && senderCertificate(uuidOnly: false, certificateExpirationPolicy: .permissive) != nil
    }
    #endif

    func setSenderCertificate(uuidOnly: Bool, certificateData: Data) {
        databaseStorage.write { transaction in
            self.keyValueStore.setDate(Date(), key: self.senderCertificateDateKey(uuidOnly: uuidOnly), transaction: transaction)
            self.keyValueStore.setData(certificateData, key: self.senderCertificateKey(uuidOnly: uuidOnly), transaction: transaction)
        }
    }

    @objc
    public func removeSenderCertificates(transaction: SDSAnyWriteTransaction) {
        keyValueStore.removeValue(forKey: senderCertificateDateKey(uuidOnly: true), transaction: transaction)
        keyValueStore.removeValue(forKey: senderCertificateKey(uuidOnly: true), transaction: transaction)
        keyValueStore.removeValue(forKey: senderCertificateDateKey(uuidOnly: false), transaction: transaction)
        keyValueStore.removeValue(forKey: senderCertificateKey(uuidOnly: false), transaction: transaction)
    }

    private func senderCertificateKey(uuidOnly: Bool) -> String {
        let baseKey = TSConstants.isUsingProductionService ? kUDCurrentSenderCertificateKey_Production : kUDCurrentSenderCertificateKey_Staging
        if uuidOnly {
            return "\(baseKey)-withoutPhoneNumber"
        } else {
            return baseKey
        }
    }

    private func senderCertificateDateKey(uuidOnly: Bool) -> String {
        let baseKey = TSConstants.isUsingProductionService ? kUDCurrentSenderCertificateDateKey_Production : kUDCurrentSenderCertificateDateKey_Staging
        if uuidOnly {
            return "\(baseKey)-withoutPhoneNumber"
        } else {
            return baseKey
        }
    }
    
    // MARK: - Unrestricted Access

    @objc
    public func shouldAllowUnrestrictedAccessLocal() -> Bool {
        return databaseStorage.read { transaction in
            self.keyValueStore.getBool(self.kUDUnrestrictedAccessKey, defaultValue: false, transaction: transaction)
        }
    }

    @objc
    public func setShouldAllowUnrestrictedAccessLocal(_ value: Bool) {
        databaseStorage.write { transaction in
            self.keyValueStore.setBool(value, key: self.kUDUnrestrictedAccessKey, transaction: transaction)
        }
    }

    // MARK: - Phone Number Sharing

    private static var phoneNumberSharingModeKey: String { "phoneNumberSharingMode" }
    private var phoneNumberSharingModeCached = AtomicOptional<PhoneNumberSharingMode>(nil)

    public var phoneNumberSharingMode: PhoneNumberSharingMode {
        guard FeatureFlags.phoneNumberSharing else { return .everybody }
        return phoneNumberSharingModeCached.get() ?? .everybody
    }

    private func cachePhoneNumberSharingMode(transaction: GRDBReadTransaction) {
        
    }

    public func setPhoneNumberSharingMode(
        _ mode: PhoneNumberSharingMode,
        updateStorageService: Bool,
        transaction: GRDBWriteTransaction
    ) {
        guard FeatureFlags.phoneNumberSharing else { return }

        keyValueStore.setInt(mode.rawValue, key: Self.phoneNumberSharingModeKey, transaction: transaction.asAnyWrite)
        phoneNumberSharingModeCached.set(mode)

        if updateStorageService {
            transaction.addSyncCompletion {
                Self.storageServiceManager.recordPendingLocalAccountUpdates()
            }
        }
    }
}

// MARK: -

@objc
public enum PhoneNumberSharingMode: Int {
    case everybody
    case contactsOnly
    case nobody
}
