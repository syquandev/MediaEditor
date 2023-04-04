//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation

// Every time we add a new property to TSOutgoingMessage, we should:
//
// * Add that property here.
// * Handle that property for received sync transcripts.
// * Handle that property in the test factories.
@objc
public class TSOutgoingMessageBuilder: TSMessageBuilder {
    @objc
    public var isVoiceMessage = false
    @objc
    public var groupMetaMessage: TSGroupMetaMessage = .unspecified
    @objc
    public var changeActionsProtoData: Data?
    @objc
    public var additionalRecipients: [SignalServiceAddress]?

    public required init(thread: TSThread,
                         timestamp: UInt64? = nil,
                         messageBody: String? = nil,
                         attachmentIds: [String]? = nil,
                         expiresInSeconds: UInt32 = 0,
                         expireStartedAt: UInt64 = 0,
                         isVoiceMessage: Bool = false,
                         groupMetaMessage: TSGroupMetaMessage = .unspecified,
                         linkPreview: OWSLinkPreview? = nil,
                         isViewOnceMessage: Bool = false,
                         changeActionsProtoData: Data? = nil,
                         additionalRecipients: [SignalServiceAddress]? = nil,
                         storyAuthorAddress: SignalServiceAddress? = nil,
                         storyTimestamp: UInt64? = nil,
                         storyReactionEmoji: String? = nil) {

        super.init(thread: thread,
                   timestamp: timestamp,
                   messageBody: messageBody,
                   attachmentIds: attachmentIds,
                   expiresInSeconds: expiresInSeconds,
                   expireStartedAt: expireStartedAt,
                   linkPreview: linkPreview,
                   isViewOnceMessage: isViewOnceMessage,
                   storyAuthorAddress: storyAuthorAddress,
                   storyTimestamp: storyTimestamp,
                   storyReactionEmoji: storyReactionEmoji)

        self.isVoiceMessage = isVoiceMessage
        self.groupMetaMessage = groupMetaMessage
        self.changeActionsProtoData = changeActionsProtoData
        self.additionalRecipients = additionalRecipients
    }

    @objc
    public class func outgoingMessageBuilder(thread: TSThread) -> TSOutgoingMessageBuilder {
        return TSOutgoingMessageBuilder(thread: thread)
    }

    @objc
    public class func outgoingMessageBuilder(thread: TSThread,
                                             messageBody: String?) -> TSOutgoingMessageBuilder {
        return TSOutgoingMessageBuilder(thread: thread,
                                        messageBody: messageBody)
    }

    // This factory method can be used at call sites that want
    // to specify every property; usage will fail to compile if
    // if any property is missing.
    @objc
    public class func builder(thread: TSThread,
                              timestamp: UInt64,
                              messageBody: String?,
                              attachmentIds: [String]?,
                              expiresInSeconds: UInt32,
                              expireStartedAt: UInt64,
                              isVoiceMessage: Bool,
                              groupMetaMessage: TSGroupMetaMessage,
                              linkPreview: OWSLinkPreview?,
                              isViewOnceMessage: Bool,
                              changeActionsProtoData: Data?,
                              additionalRecipients: [SignalServiceAddress]?,
                              storyAuthorAddress: SignalServiceAddress?,
                              storyTimestamp: NSNumber?,
                              storyReactionEmoji: String?) -> TSOutgoingMessageBuilder {
        return TSOutgoingMessageBuilder(thread: thread,
                                        timestamp: timestamp,
                                        messageBody: messageBody,
                                        attachmentIds: attachmentIds,
                                        expiresInSeconds: expiresInSeconds,
                                        expireStartedAt: expireStartedAt,
                                        isVoiceMessage: isVoiceMessage,
                                        groupMetaMessage: groupMetaMessage,
                                        linkPreview: linkPreview,
                                        isViewOnceMessage: isViewOnceMessage,
                                        changeActionsProtoData: changeActionsProtoData,
                                        additionalRecipients: additionalRecipients,
                                        storyAuthorAddress: storyAuthorAddress,
                                        storyTimestamp: storyTimestamp?.uint64Value,
                                        storyReactionEmoji: storyReactionEmoji)
    }

    private var hasBuilt = false

    @objc
    public func build() -> TSOutgoingMessage {
        if hasBuilt {
            owsFailDebug("Don't build more than once.")
        }
        hasBuilt = true
        return TSOutgoingMessage(outgoingMessageWithBuilder: self)
    }
}

public extension TSOutgoingMessage {
    @objc func failedRecipientAddresses(errorCode: Int) -> [SignalServiceAddress] {
        guard let states = recipientAddressStates else { return [] }

        return states.filter { _, state in
            return state.state == .failed && state.errorCode?.intValue == errorCode
        }.map { $0.key }
    }

    @objc
    var canSendWithSenderKey: Bool {
        // Sometimes we can fail to send a SenderKey message for an unknown reason. For example,
        // the server may reject the message because one of our recipients has an invalid access
        // token, but we don't know which recipient is the culprit. If we ever hit any of these
        // non-transient failures, we should not send this message with sender key.
        //
        // By sending the message with traditional fanout, this *should* put things in order so
        // that our next SenderKey message will send successfully.
        return true
    }
}

// MARK: Sender Key + Message Send Log

@objc
enum EncryptionStyle: Int {
    case whisper
    case plaintext
}

extension TSOutgoingMessage {

    /// A collection of message unique IDs related to the outgoing message
    ///
    /// Used to help prune the Message Send Log. For example, a properly annotated outgoing reaction
    /// message will automatically be deleted from the Message Send Log when the reacted message is
    /// deleted.
    ///
    /// Subclasses should override to include any interactionIds their specific subclass relates to. Subclasses
    /// *probably* want to return a union with the results of their parent class' implementation
    @objc
    var relatedUniqueIds: Set<String> {
        Set([self.uniqueId])
    }

    @objc
    func envelopeGroupIdWithTransaction(_ transaction: SDSAnyReadTransaction) -> Data? {
        return Data()
    }

    /// Indicates whether or not this message's proto should be saved into the MessageSendLog
    ///
    /// Anything high volume or time-dependent (typing indicators, calls, etc.) should set this false.
    /// A non-resendable content hint does not necessarily mean this should be false set false (though
    /// it is a good indicator)
    @objc
    var shouldRecordSendLog: Bool { true }

    /// Used in MessageSender to signal how a message should be encrypted before sending
    /// Currently only overridden by OWSOutgoingResendRequest (this is asserted in the MessageSender implementation)
    @objc
    var encryptionStyle: EncryptionStyle { .whisper }
}
