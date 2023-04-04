//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation

public extension TSMessage {

    @objc
    var isOutgoing: Bool { self as? TSOutgoingMessage != nil }

    // MARK: - Attachments

    func failedAttachments(transaction: SDSAnyReadTransaction) -> [TSAttachmentPointer] {
        let attachments: [TSAttachment] = allAttachments(with: transaction.unwrapGrdbRead)
        let states: [TSAttachmentPointerState] = [.failed]
        return Self.onlyAttachmentPointers(attachments: attachments, withStateIn: Set(states))
    }

    func failedOrPendingAttachments(transaction: SDSAnyReadTransaction) -> [TSAttachmentPointer] {
        let attachments: [TSAttachment] = allAttachments(with: transaction.unwrapGrdbRead)
        let states: [TSAttachmentPointerState] = [.failed, .pendingMessageRequest, .pendingManualDownload]
        return Self.onlyAttachmentPointers(attachments: attachments, withStateIn: Set(states))
    }

    func failedBodyAttachments(transaction: SDSAnyReadTransaction) -> [TSAttachmentPointer] {
        let attachments: [TSAttachment] = bodyAttachments(with: transaction.unwrapGrdbRead)
        let states: [TSAttachmentPointerState] = [.failed]
        return Self.onlyAttachmentPointers(attachments: attachments, withStateIn: Set(states))
    }

    func pendingBodyAttachments(transaction: SDSAnyReadTransaction) -> [TSAttachmentPointer] {
        let attachments: [TSAttachment] = bodyAttachments(with: transaction.unwrapGrdbRead)
        let states: [TSAttachmentPointerState] = [.pendingMessageRequest, .pendingManualDownload]
        return Self.onlyAttachmentPointers(attachments: attachments, withStateIn: Set(states))
    }

    private static func onlyAttachmentPointers(attachments: [TSAttachment],
                                               withStateIn states: Set<TSAttachmentPointerState>) -> [TSAttachmentPointer] {
        return attachments.compactMap { attachment -> TSAttachmentPointer? in
            guard let attachmentPointer = attachment as? TSAttachmentPointer else {
                return nil
            }
            guard states.contains(attachmentPointer.state) else {
                return nil
            }
            return attachmentPointer
        }
    }

    @objc(removeReactionForReactor:transaction:)
    func removeReaction(for reactor: SignalServiceAddress, transaction: SDSAnyWriteTransaction) {
        Logger.info("")
    }

    // MARK: - Remote Delete

    // A message can be remotely deleted iff:
    //  * you sent this message
    //  * you haven't already remotely deleted this message
    //  * it has been less than 3 hours since you sent the message
    var canBeRemotelyDeleted: Bool {
        guard let outgoingMessage = self as? TSOutgoingMessage else { return false }
        guard !outgoingMessage.wasRemotelyDeleted else { return false }
        guard Date.ows_millisecondTimestamp() - outgoingMessage.timestamp <= (kHourInMs * 3) else { return false }

        return true
    }

    @objc(OWSRemoteDeleteProcessingResult)
    enum RemoteDeleteProcessingResult: Int, Error {
        case deletedMessageMissing
        case invalidDelete
        case success
    }

    @objc
    class func tryToRemotelyDeleteMessage(
        fromAddress authorAddress: SignalServiceAddress,
        sentAtTimestamp: UInt64,
        threadUniqueId: String,
        serverTimestamp: UInt64,
        transaction: SDSAnyWriteTransaction
    ) -> RemoteDeleteProcessingResult {
        if let messageToDelete = InteractionFinder.findMessage(
            withTimestamp: sentAtTimestamp,
            threadId: threadUniqueId,
            author: authorAddress,
            transaction: transaction
        ) {
            if messageToDelete is TSOutgoingMessage, authorAddress.isLocalAddress {
                messageToDelete.markMessageAsRemotelyDeleted(transaction: transaction)
                return .success
            }
        }else {
            // The message doesn't exist locally, so nothing to do.
            Logger.info("Attempted to remotely delete a message that doesn't exist \(sentAtTimestamp)")
            return .deletedMessageMissing
        }
        return .deletedMessageMissing
    }

    private func markMessageAsRemotelyDeleted(transaction: SDSAnyWriteTransaction) {
        updateWithRemotelyDeletedAndRemoveRenderableContent(with: transaction)
    }
}
