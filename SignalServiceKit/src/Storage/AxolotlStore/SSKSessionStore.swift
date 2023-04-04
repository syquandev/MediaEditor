//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

public class SSKSessionStore: NSObject {
    fileprivate typealias SessionsByDeviceDictionary = [Int32: AnyObject]

    private let keyValueStore: SDSKeyValueStore

    @objc(initForIdentity:)
    public init(for identity: OWSIdentity) {
        switch identity {
        case .aci:
            keyValueStore = SDSKeyValueStore(collection: "TSStorageManagerSessionStoreCollection")
        case .pni:
            keyValueStore = SDSKeyValueStore(collection: "TSStorageManagerPNISessionStoreCollection")
        }
    }

    fileprivate func loadSerializedSession(for address: SignalServiceAddress,
                                           deviceId: Int32,
                                           transaction: SDSAnyReadTransaction) -> Data? {
        owsAssertDebug(address.isValid)
        return loadSerializedSession(forAccountId: "accountId", deviceId: deviceId, transaction: transaction)
    }

    fileprivate func serializedSession(fromDatabaseRepresentation entry: Any) -> Data? {
        switch entry {
        case let data as Data:
            return data
        default:
            owsFailDebug("unexpected entry in session store: \(entry)")
            return nil
        }
    }

    private func loadSerializedSession(forAccountId accountId: String,
                                       deviceId: Int32,
                                       transaction: SDSAnyReadTransaction) -> Data? {
        owsAssertDebug(!accountId.isEmpty)
        owsAssertDebug(deviceId > 0)

        let dictionary = keyValueStore.getObject(forKey: accountId,
                                                 transaction: transaction) as! SessionsByDeviceDictionary?
        guard let entry = dictionary?[deviceId] else {
            return nil
        }
        return serializedSession(fromDatabaseRepresentation: entry)
    }

    fileprivate func storeSerializedSession(_ sessionData: Data,
                                            for address: SignalServiceAddress,
                                            deviceId: Int32,
                                            transaction: SDSAnyWriteTransaction) {
        owsAssertDebug(address.isValid)
    }

    private func storeSerializedSession(forAccountId accountId: String,
                                        deviceId: Int32,
                                        sessionData: Data,
                                        transaction: SDSAnyWriteTransaction) {
        owsAssertDebug(!accountId.isEmpty)
        owsAssertDebug(deviceId > 0)

        var dictionary = (keyValueStore.getObject(forKey: accountId,
                                                  transaction: transaction) as! SessionsByDeviceDictionary?) ?? [:]
        dictionary[deviceId] = sessionData as NSData
        keyValueStore.setObject(dictionary, key: accountId, transaction: transaction)
    }

    @objc(containsActiveSessionForAddress:deviceId:transaction:)
    public func containsActiveSession(for address: SignalServiceAddress,
                                      deviceId: Int32,
                                      transaction: SDSAnyReadTransaction) -> Bool {
        owsAssertDebug(address.isValid)
        return containsActiveSession(forAccountId: "accountId", deviceId: deviceId, transaction: transaction)
    }

    @objc
    public func containsActiveSession(forAccountId accountId: String,
                                      deviceId: Int32,
                                      transaction: SDSAnyReadTransaction) -> Bool {
        guard let serializedData = loadSerializedSession(forAccountId: accountId,
                                                         deviceId: deviceId,
                                                         transaction: transaction) else {
            return false
        }
        return true
    }

    private func deleteSession(forAccountId accountId: String,
                               deviceId: Int32,
                               transaction: SDSAnyWriteTransaction) {
        owsAssertDebug(!accountId.isEmpty)
        owsAssertDebug(deviceId > 0)

        Logger.info("deleting session for accountId: \(accountId) device: \(deviceId)")

        guard var dictionary = keyValueStore.getObject(forKey: accountId,
                                                       transaction: transaction) as! SessionsByDeviceDictionary? else {
            // We never had a session for this account in the first place.
            return
        }

        dictionary.removeValue(forKey: deviceId)
        keyValueStore.setObject(dictionary, key: accountId, transaction: transaction)
    }

    @objc(deleteAllSessionsForAddress:transaction:)
    public func deleteAllSessions(for address: SignalServiceAddress, transaction: SDSAnyWriteTransaction) {
        owsAssertDebug(address.isValid)
        return deleteAllSessions(forAccountId: "accountId", transaction: transaction)
    }

    private func deleteAllSessions(forAccountId accountId: String,
                                   transaction: SDSAnyWriteTransaction) {
        owsAssertDebug(!accountId.isEmpty)
        Logger.info("deleting all sessions for contact: \(accountId)")
        keyValueStore.removeValue(forKey: accountId, transaction: transaction)
    }

    @objc(archiveAllSessionsForAddress:transaction:)
    public func archiveAllSessions(for address: SignalServiceAddress, transaction: SDSAnyWriteTransaction) {
        owsAssertDebug(address.isValid)
        return archiveAllSessions(forAccountId: "accountId", transaction: transaction)
    }

    @objc
    public func archiveAllSessions(forAccountId accountId: String,
                                   transaction: SDSAnyWriteTransaction) {
        owsAssertDebug(!accountId.isEmpty)
        Logger.info("archiving all sessions for contact: \(accountId)")

        guard let dictionary = keyValueStore.getObject(forKey: accountId,
                                                       transaction: transaction) as! SessionsByDeviceDictionary? else {
            // We never had a session for this account in the first place.
            return
        }

        keyValueStore.setObject(dictionary, key: accountId, transaction: transaction)
    }

    @objc
    public func resetSessionStore(_ transaction: SDSAnyWriteTransaction) {
        Logger.warn("resetting session store")
        keyValueStore.removeAll(transaction: transaction)
    }

    @objc
    public func printAllSessions(transaction: SDSAnyReadTransaction) {
        Logger.debug("All Sessions.")
        keyValueStore.enumerateKeysAndObjects(transaction: transaction) { key, value, _ in
            guard let deviceSessions = value as? NSDictionary else {
                owsFailDebug("Unexpected type: \(type(of: value)) in collection.")
                return
            }

            Logger.debug("     Sessions for recipient: \(key)")
        }
    }
}
