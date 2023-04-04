//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation

// Every time we add a new property to TSMessage, we should:
//
// * Add that property here.
// * Handle that property for received sync transcripts.
// * Handle that property in the test factories.
@objc
public class TSMessageBuilder: NSObject {
    @objc
    public let thread: TSThread
    @objc
    public var timestamp: UInt64 = NSDate.ows_millisecondTimeStamp()
    @objc
    public var messageBody: String?
    @objc
    public var attachmentIds = [String]()
    @objc
    public var expiresInSeconds: UInt32 = 0
    @objc
    public var expireStartedAt: UInt64 = 0
    @objc
    public var linkPreview: OWSLinkPreview?
    @objc
    public var isViewOnceMessage = false
    @objc
    public var storyAuthorAddress: SignalServiceAddress?
    @objc
    public var storyTimestamp: NSNumber?
    @objc
    public var storyReactionEmoji: String?
    @objc
    public var isGroupStoryReply: Bool {
        storyAuthorAddress != nil && storyTimestamp != nil && thread.isGroupThread
    }

    init(thread: TSThread,
         timestamp: UInt64? = nil,
         messageBody: String? = nil,
         attachmentIds: [String]? = nil,
         expiresInSeconds: UInt32 = 0,
         expireStartedAt: UInt64 = 0,
         linkPreview: OWSLinkPreview? = nil,
         isViewOnceMessage: Bool = false,
         storyAuthorAddress: SignalServiceAddress? = nil,
         storyTimestamp: UInt64? = nil,
         storyReactionEmoji: String? = nil) {
        self.thread = thread

        if let timestamp = timestamp {
            self.timestamp = timestamp
        }
        self.messageBody = messageBody
        if let attachmentIds = attachmentIds {
            self.attachmentIds = attachmentIds
        }
        self.expiresInSeconds = expiresInSeconds
        self.expireStartedAt = expireStartedAt
        self.linkPreview = linkPreview
        self.isViewOnceMessage = isViewOnceMessage
        self.storyAuthorAddress = storyAuthorAddress
        self.storyTimestamp = storyTimestamp.map { NSNumber(value: $0) }
        self.storyReactionEmoji = storyReactionEmoji
    }

    @objc
    public class func messageBuilder(thread: TSThread) -> TSMessageBuilder {
        return TSMessageBuilder(thread: thread)
    }

    @objc
    public class func messageBuilder(thread: TSThread,
                                     messageBody: String?) -> TSMessageBuilder {
        return TSMessageBuilder(thread: thread,
                                messageBody: messageBody)
    }

    @objc
    public class func messageBuilder(thread: TSThread,
                                     timestamp: UInt64,
                                     messageBody: String?) -> TSMessageBuilder {
        return TSMessageBuilder(thread: thread,
                                timestamp: timestamp,
                                messageBody: messageBody)
    }

    #if TESTABLE_BUILD
    @objc
    public func addAttachmentId(_ attachmentId: String) {
        attachmentIds = attachmentIds + [attachmentId ]
    }
    #endif
}
