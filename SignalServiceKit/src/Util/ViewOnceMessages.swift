//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalCoreKit

@objc
public class ViewOnceMessages: NSObject {

    @objc
    public required override init() {
        super.init()

        if CurrentAppContext().isMainApp {
            AppReadiness.runNowOrWhenAppDidBecomeReadySync {
                Self.appDidBecomeReady()
            }
        }
    }

    // MARK: - Events

    private class func nowMs() -> UInt64 {
        return NSDate.ows_millisecondTimeStamp()
    }

    private class func appDidBecomeReady() {
        AssertIsOnMainThread()

        DispatchQueue.global().async {
            self.checkForAutoCompletion()
        }
    }

    // "Check for auto-completion", e.g. complete messages whether or
    // not they have been read after N days.  Also complete outgoing
    // sent messages. We need to repeat this check periodically while
    // the app is running.
    private class func checkForAutoCompletion() {
        // Find all view-once messages which are not yet complete.
        // Complete messages if necessary.
        databaseStorage.write { (transaction) in
            let messages = AnyViewOnceMessageFinder().allMessagesWithViewOnceMessage(transaction: transaction)
            for message in messages {
                completeIfNecessary(message: message, transaction: transaction)
            }
        }

        // We need to "check for auto-completion" once per day.
        DispatchQueue.global().asyncAfter(wallDeadline: .now() + kDayInterval) {
            self.checkForAutoCompletion()
        }
    }

    @objc
    public class func completeIfNecessary(message: TSMessage,
                                          transaction: SDSAnyWriteTransaction) {

        guard message.isViewOnceMessage,
            !message.isViewOnceComplete else {
            return
        }

        // If message should auto-complete, complete.
        guard !shouldMessageAutoComplete(message) else {
            markAsComplete(message: message,
                           sendSyncMessages: true,
                           transaction: transaction)
            return
        }

        // If outgoing message and is "sent", complete.
        guard !isOutgoingSent(message: message) else {
            markAsComplete(message: message,
                           sendSyncMessages: true,
                           transaction: transaction)
            return
        }

        // Message should not yet complete.
    }

    private class func isOutgoingSent(message: TSMessage) -> Bool {
        guard message.isViewOnceMessage else {
            owsFailDebug("Unexpected message.")
            return false
        }
        // If outgoing message and is "sent", complete.
        guard let outgoingMessage = message as? TSOutgoingMessage else {
            return false
        }
        guard outgoingMessage.messageState == .sent else {
            return false
        }
        return true
    }

    // We auto-complete messages after 30 days, even if the user hasn't seen them.
    private class func shouldMessageAutoComplete(_ message: TSMessage) -> Bool {
        let autoCompleteDeadlineMs = min(message.timestamp, message.receivedAtTimestamp) + 30 * kDayInMs
        return nowMs() >= autoCompleteDeadlineMs
    }

    @objc
    public class func markAsComplete(message: TSMessage,
                                     sendSyncMessages: Bool,
                                     transaction: SDSAnyWriteTransaction) {
        guard message.isViewOnceMessage else {
            owsFailDebug("Not a view-once message.")
            return
        }
        guard !message.isViewOnceComplete else {
            // Already completed, no need to complete again.
            return
        }
        message.updateWithViewOnceCompleteAndRemoveRenderableContent(with: transaction)

        if sendSyncMessages {
            sendSyncMessage(forMessage: message, transaction: transaction)
        }
    }

    // MARK: - Sync Messages

    private class func sendSyncMessage(forMessage message: TSMessage,
                                       transaction: SDSAnyWriteTransaction) {
    }

    @objc(OWSViewOnceSyncMessageProcessingResult)
    public enum ViewOnceSyncMessageProcessingResult: Int, Error {
        case associatedMessageMissing
        case invalidSyncMessage
        case success
    }
}

// MARK: -

public protocol ViewOnceMessageFinder {
    associatedtype ReadTransaction

    typealias EnumerateTSMessageBlock = (TSMessage, UnsafeMutablePointer<ObjCBool>) -> Void

    func allMessagesWithViewOnceMessage(transaction: ReadTransaction) -> [TSMessage]
    func enumerateAllIncompleteViewOnceMessages(transaction: ReadTransaction, block: @escaping EnumerateTSMessageBlock)
}

// MARK: -

extension ViewOnceMessageFinder {

    public func allMessagesWithViewOnceMessage(transaction: ReadTransaction) -> [TSMessage] {
        var result: [TSMessage] = []
        self.enumerateAllIncompleteViewOnceMessages(transaction: transaction) { message, _ in
            result.append(message)
        }
        return result
    }
}

// MARK: -

public class AnyViewOnceMessageFinder {
    lazy var grdbAdapter = GRDBViewOnceMessageFinder()
}

// MARK: -

extension AnyViewOnceMessageFinder: ViewOnceMessageFinder {
    public func enumerateAllIncompleteViewOnceMessages(transaction: SDSAnyReadTransaction, block: @escaping EnumerateTSMessageBlock) {
        switch transaction.readTransaction {
        case .grdbRead(let grdbRead):
            grdbAdapter.enumerateAllIncompleteViewOnceMessages(transaction: grdbRead, block: block)
        }
    }
}

// MARK: -

class GRDBViewOnceMessageFinder: ViewOnceMessageFinder {
    func enumerateAllIncompleteViewOnceMessages(transaction: GRDBReadTransaction, block: @escaping EnumerateTSMessageBlock) {

        let sql = """
        SELECT * FROM \(InteractionRecord.databaseTableName)
        WHERE \(interactionColumn: .isViewOnceMessage) IS NOT NULL
        AND \(interactionColumn: .isViewOnceMessage) == TRUE
        AND \(interactionColumn: .isViewOnceComplete) IS NOT NULL
        AND \(interactionColumn: .isViewOnceComplete) == FALSE
        """

        let cursor = TSInteraction.grdbFetchCursor(sql: sql,
                                                   transaction: transaction)
        var stop: ObjCBool = false
        // GRDB TODO make cursor.next fail hard to remove this `try!`
        while let next = try! cursor.next() {
            guard let message = next as? TSMessage else {
                owsFailDebug("expecting message but found: \(next)")
                return
            }
            guard message.isViewOnceMessage,
                !message.isViewOnceComplete else {
                    owsFailDebug("expecting incomplete view-once message but found: \(message)")
                    return
            }
            block(message, &stop)
            if stop.boolValue {
                return
            }
        }
    }
}
