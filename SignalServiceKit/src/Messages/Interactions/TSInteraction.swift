//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalCoreKit

extension TSInteraction {

    @objc
    public func fillInMissingSortIdForJustInsertedInteraction(transaction: SDSAnyReadTransaction) {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            fillInMissingSortIdForJustInsertedInteraction(transaction: grdbRead)
        }
    }

    private func fillInMissingSortIdForJustInsertedInteraction(transaction: GRDBReadTransaction) {
        guard self.sortId == 0 else {
            owsFailDebug("Unexpected sortId: \(sortId).")
            return
        }
        guard let sortId = BaseModelX.grdbIdByUniqueId(tableMetadata: TSInteractionSerializer.table,
                                                      uniqueIdColumnName: InteractionRecord.columnName(.uniqueId),
                                                      uniqueIdColumnValue: self.uniqueId,
                                                      transaction: transaction) else {
            owsFailDebug("Missing sortId.")
            return
        }
        guard sortId > 0, sortId <= UInt64.max else {
            owsFailDebug("Invalid sortId: \(sortId).")
            return
        }
        self.replaceSortId(UInt64(sortId))
        owsAssertDebug(self.sortId > 0)
    }

    /// Returns whether the given interaction should pull a conversation to the top of the list and
    /// marked unread.
    ///
    /// This operation necessarily happens after the interaction has been pulled out of the
    /// database. If possible, they should also be filtered as part of the database queries in the
    /// `mostRecentInteractionForInbox(transaction:)` implementations in InteractionFinder.swift.
    @objc
    public func shouldAppearInInbox(transaction: SDSAnyReadTransaction) -> Bool {
        if !shouldBeSaved || isDynamicInteraction{
            owsFailDebug("Unexpected interaction type: \(type(of: self))")
            return false
        }
        return false
    }

    /// Returns `true` if the receiver was inserted into the database by updating the placeholder
    /// Returns `false` if the receiver needs to be inserted into the database.
    private func updatePlaceholder(
        from sender: SignalServiceAddress,
        transaction: SDSAnyWriteTransaction
    ) -> Bool {
        let _: [TSInteraction]
        Logger.info("Fetched placeholder with timestamp: \(timestamp) from sender: \(sender). Performing replacement...")
        return true
    }

    @objc
    public func insertOrReplacePlaceholder(from sender: SignalServiceAddress, transaction: SDSAnyWriteTransaction) {
        if updatePlaceholder(from: sender, transaction: transaction) {
            Logger.info("Successfully replaced placeholder with interaction: \(timestamp)")
        } else {
            anyInsert(transaction: transaction)

            // Replaced interactions will inherit the existing sortId
            // Inserted interactions will be assigned a sortId from SQLite, but
            // we need to fetch from the database.
            owsAssertDebug(sortId == 0)
            fillInMissingSortIdForJustInsertedInteraction(transaction: transaction)
            owsAssertDebug(sortId > 0)
        }
    }
}
