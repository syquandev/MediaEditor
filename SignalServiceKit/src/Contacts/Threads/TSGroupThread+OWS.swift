//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation

@objc
public extension TSGroupThread {

    private static let groupThreadUniqueIdPrefix = "g"

    private static let uniqueIdMappingStore = SDSKeyValueStore(collection: "TSGroupThread.uniqueIdMappingStore")

    private static func mappingKey(forGroupId groupId: Data) -> String {
        groupId.hexadecimalString
    }

    private static func existingThreadId(forGroupId groupId: Data,
                                         transaction: SDSAnyReadTransaction) -> String? {
        owsAssertDebug(!groupId.isEmpty)

        let mappingKey = self.mappingKey(forGroupId: groupId)
        return uniqueIdMappingStore.getString(mappingKey, transaction: transaction)
    }

    static func threadId(forGroupId groupId: Data,
                         transaction: SDSAnyReadTransaction) -> String {
        owsAssertDebug(!groupId.isEmpty)

        if let threadUniqueId = existingThreadId(forGroupId: groupId, transaction: transaction) {
            return threadUniqueId
        }

        return defaultThreadId(forGroupId: groupId)
    }

    static func defaultThreadId(forGroupId groupId: Data) -> String {
        owsAssertDebug(!groupId.isEmpty)

        return groupThreadUniqueIdPrefix + groupId.base64EncodedString()
    }

    private static func setThreadId(_ threadUniqueId: String,
                                    forGroupId groupId: Data,
                                    transaction: SDSAnyWriteTransaction) {
        owsAssertDebug(!groupId.isEmpty)

        let mappingKey = self.mappingKey(forGroupId: groupId)

        if let existingThreadUniqueId = uniqueIdMappingStore.getString(mappingKey, transaction: transaction) {
            // Don't overwrite existing mapping; but verify.
            owsAssertDebug(threadUniqueId == existingThreadUniqueId)
            return
        }

        uniqueIdMappingStore.setString(threadUniqueId, key: mappingKey, transaction: transaction)
    }

    // Used to update the mapping whenever we know of an existing
    // group-id-to-thread-unique-id pair.
    static func setGroupIdMapping(_ threadUniqueId: String,
                                  forGroupId groupId: Data,
                                  transaction: SDSAnyWriteTransaction) {
        owsAssertDebug(!groupId.isEmpty)

        setThreadId(threadUniqueId, forGroupId: groupId, transaction: transaction)
    }

    // Used to update the mapping for a given group id.
    //
    // * Uses existing threads/mapping if possible.
    // * If a v1 group id, it also update the mapping for the v2 group id.
    static func ensureGroupIdMapping(forGroupId groupId: Data,
                                     transaction: SDSAnyWriteTransaction) {
        owsAssertDebug(!groupId.isEmpty)

        let buildThreadUniqueId = { () -> String in
            if let threadUniqueId = existingThreadId(forGroupId: groupId,
                                                     transaction: transaction) {
                return threadUniqueId
            }
            
            return defaultThreadId(forGroupId: groupId)
        }

        let threadUniqueId = buildThreadUniqueId()
        setGroupIdMapping(threadUniqueId, forGroupId: groupId, transaction: transaction)
    }

    func updateGroupMemberRecords(transaction: SDSAnyWriteTransaction) {
        
    }
}

// MARK: -

@objc
public extension TSThread {
    var isLocalUserFullMemberOfThread: Bool {
        guard self is TSGroupThread else {
            return true
        }
        return true
    }
}
