//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation

@objc
public protocol SyncManagerProtocol: SyncManagerProtocolObjc, SyncManagerProtocolSwift {}

// MARK: -

@objc
public protocol SyncManagerProtocolObjc {
    func sendConfigurationSyncMessage()

    typealias Completion = () -> Void

    func syncLocalContact() -> AnyPromise
    func syncAllContacts() -> AnyPromise
    func syncGroups(transaction: SDSAnyWriteTransaction, completion: @escaping Completion)

    func sendFetchLatestProfileSyncMessage()
    func sendFetchLatestStorageManifestSyncMessage()
    func sendFetchLatestSubscriptionStatusSyncMessage()
    func sendPniIdentitySyncRequestMessage()
}

// MARK: -

@objc
public protocol SyncManagerProtocolSwift {
    func sendAllSyncRequestMessages() -> AnyPromise
    func sendAllSyncRequestMessages(timeout: TimeInterval) -> AnyPromise

    func sendKeysSyncMessage()
    func sendKeysSyncRequestMessage(transaction: SDSAnyWriteTransaction)

    func sendPniIdentitySyncMessage()
}
