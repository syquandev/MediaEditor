//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation

/**
 * Strings re-used in multiple places should be added here.
 */
@objc
public class CommonStrings: NSObject {

    @objc
    static public var archiveAction: String {
        "ARCHIVE_ACTION"
    }

    @objc
    static public var backButton: String {
        "BACK_BUTTON"
    }

    @objc
    static public var continueButton: String {
        "BUTTON_CONTINUE"
    }

    @objc
    static public var dismissButton: String {
        "DISMISS_BUTTON_TEXT"
    }

    @objc
    static public var cancelButton: String {
        "TXT_CANCEL_TITLE"
    }

    @objc
    static public var selectButton: String {
        "BUTTON_SELECT"
    }

    @objc
    static public var doneButton: String {
        "BUTTON_DONE"
    }

    @objc
    static public var nextButton: String {
        "BUTTON_NEXT"
    }

    @objc
    static public var previousButton: String {
        "BUTTON_PREVIOUS"
    }

    @objc
    static public var skipButton: String {
        "NAVIGATION_ITEM_SKIP_BUTTON"
    }

    @objc
    static public var deleteButton: String {
        "TXT_DELETE_TITLE"
    }

    @objc
    static public var deleteForMeButton: String {
            "MESSAGE_ACTION_DELETE_FOR_YOU"
    }

    @objc
    static public var retryButton: String {
        "RETRY_BUTTON_TEXT"
    }

    @objc
    static public var okayButton: String {
        "BUTTON_OKAY"
    }

    @objc
    static public var okButton: String {
        "OK"
    }

    @objc
    static public var copyButton: String {
        "BUTTON_COPY"
    }

    @objc
    static public var setButton: String {
        "BUTTON_SET"
    }

    @objc
    static public var editButton: String {
        "BUTTON_EDIT"
    }

    @objc
    static public var saveButton: String {
        "ALERT_SAVE"
    }

    @objc
    static public var shareButton: String {
        "BUTTON_SHARE"
    }

    @objc
    static public var help: String {
        "SETTINGS_HELP"
    }

    @objc
    static public var openSettingsButton: String {
        "OPEN_SETTINGS_BUTTON"
    }

    @objc
    static public var errorAlertTitle: String {
        "ALERT_ERROR_TITLE"
    }

    @objc
    static public var searchPlaceholder: String {
       "SEARCH_FIELD_PLACE_HOLDER_TEXT"
    }

    @objc
    static public var mainPhoneNumberLabel: String {
        "PHONE_NUMBER_TYPE_MAIN"
    }

    @objc
    static public var contactSupport: String {
        "CONTACT_SUPPORT"
    }

    @objc
    static public var learnMore: String {
        "LEARN_MORE"
    }

    @objc
    static public var unarchiveAction: String {
        "UNARCHIVE_ACTION"
    }

    @objc
    static public var readAction: String {
        "READ_ACTION"
    }

    @objc
    static public var unreadAction: String {
        "UNREAD_ACTION"
    }

    @objc
    static public var pinAction: String {
        "PIN_ACTION"
    }

    @objc
    static public var unpinAction: String {
        "UNPIN_ACTION"
    }

    @objc
    static public var switchOn: String {
        "SWITCH_ON"
    }

    @objc
    static public var switchOff: String {
        "SWITCH_OFF"
    }

    @objc
    static public var sendMessage: String {
        "ACTION_SEND_MESSAGE"
    }

    @objc
    static public var yesButton: String {
        "BUTTON_YES"
    }

    @objc
    static public var noButton: String {
        "BUTTON_NO"
    }

    @objc
    static public var notNowButton: String {
        "BUTTON_NOT_NOW"
    }

    @objc
    static public var addButton: String {
        "BUTTON_ADD"
    }

    @objc
    static public var viewButton: String {
        "BUTTON_VIEW"
    }

    @objc
    static public var startButton: String {
        "BUTTON_START"
    }

    @objc
    static public var seeAllButton: String {
        "SEE_ALL_BUTTON"
    }

    @objc
    static public var muteButton: String {
       "BUTTON_MUTE"
    }

    @objc
    static public var unmuteButton: String {
        "BUTTON_UNMUTE"
    }

    @objc
    static public var genericError: String {
        "ALERT_ERROR_TITLE"
    }

    @objc
    static public var attachmentTypePhoto: String {
        "ATTACHMENT_TYPE_PHOTO"
    }

    @objc
    static public var attachmentTypeVideo: String {
        "ATTACHMENT_TYPE_VIDEO"
    }

    @objc
    static public var searchBarPlaceholder: String {
        "INVITE_FRIENDS_PICKER_SEARCHBAR_PLACEHOLDER"
    }
}

// MARK: -

@objc
public class CommonFormats: NSObject {
    @objc
    static public func formatUsername(_ username: String) -> String? {
        return ("USERNAME_PREFIX")
    }
}

// MARK: -

@objc
public class MessageStrings: NSObject {

    @objc
    static public var conversationIsBlocked: String {
        "CONTACT_CELL_IS_BLOCKED"
    }

    @objc
    static public var newGroupDefaultTitle: String {
        "NEW_GROUP_DEFAULT_TITLE"
    }

    @objc
    static public var replyNotificationAction: String {
        "PUSH_MANAGER_REPLY"
    }

    @objc
    static public var markAsReadNotificationAction: String {
        "PUSH_MANAGER_MARKREAD"
    }

    @objc
    static public var reactWithThumbsUpNotificationAction: String {
        "PUSH_MANAGER_REACT_WITH_THUMBS_UP"
    }

    @objc
    static public var sendButton: String {
        "SEND_BUTTON_TITLE"
    }

    @objc
    static public var noteToSelf: String {
        "NOTE_TO_SELF"
    }

    @objc
    static public var viewOnceViewPhoto: String {
        "PER_MESSAGE_EXPIRATION_VIEW_PHOTO"
    }

    @objc
    static public var viewOnceViewVideo: String {
        "PER_MESSAGE_EXPIRATION_VIEW_VIDEO"
    }

    @objc
    static public var removePreviewButtonLabel: String {
        "REMOVE_PREVIEW"
    }
}

// MARK: -

@objc
public class NotificationStrings: NSObject {
    @objc
    static public var incomingAudioCallBody: String {
        "CALL_AUDIO_INCOMING_NOTIFICATION_BODY"
    }

    @objc
    static public var incomingVideoCallBody: String {
        "CALL_VIDEO_INCOMING_NOTIFICATION_BODY"
    }

    @objc
    static public var missedCallBecauseOfIdentityChangeBody: String {
        "CALL_MISSED_BECAUSE_OF_IDENTITY_CHANGE_NOTIFICATION_BODY"
    }

    @objc
    static public var genericIncomingMessageNotification: String {
        "GENERIC_INCOMING_MESSAGE_NOTIFICATION"
    }

    /// This is the fallback message used for push notifications
    /// when the NSE or main app is unable to process them. We
    /// don't use it directly in the app, but need to maintain
    /// a reference to it for string generation.
    @objc
    static public var indeterminateIncomingMessageNotification: String {
        "APN_Message"
    }

    @objc
    static public var incomingGroupMessageTitleFormat: String {
        "NEW_GROUP_MESSAGE_NOTIFICATION_TITLE"
    }

    @objc
    static public var failedToSendBody: String {
    "SEND_FAILED_NOTIFICATION_BODY"
    }

    @objc
    static public var groupCallSafetyNumberChangeBody: String {
        "GROUP_CALL_SAFETY_NUMBER_CHANGE_BODY"
    }

    @objc
    static public var incomingReactionFormat: String {
        "REACTION_INCOMING_NOTIFICATION_BODY_FORMAT"
    }

    @objc
    static public var incomingReactionTextMessageFormat: String {
        "REACTION_INCOMING_NOTIFICATION_TO_TEXT_MESSAGE_BODY_FORMAT"
    }

    @objc
    static public var incomingReactionViewOnceMessageFormat: String {
        "REACTION_INCOMING_NOTIFICATION_TO_VIEW_ONCE_MESSAGE_BODY_FORMAT"
    }

    @objc
    static public var incomingReactionStickerMessageFormat: String {
        "REACTION_INCOMING_NOTIFICATION_TO_STICKER_MESSAGE_BODY_FORMAT"
    }

    @objc
    static public var incomingReactionContactShareMessageFormat: String {
    "REACTION_INCOMING_NOTIFICATION_TO_CONTACT_SHARE_BODY_FORMAT"
    }

    @objc
    static public var incomingReactionAlbumMessageFormat: String {
        "REACTION_INCOMING_NOTIFICATION_TO_ALBUM_BODY_FORMAT"
    }

    @objc
    static public var incomingReactionPhotoMessageFormat: String {
        "REACTION_INCOMING_NOTIFICATION_TO_PHOTO_BODY_FORMAT"
    }

    @objc
    static public var incomingReactionVideoMessageFormat: String {
        "REACTION_INCOMING_NOTIFICATION_TO_VIDEO_BODY_FORMAT"
    }

    @objc
    static public var incomingReactionVoiceMessageFormat: String {
        "REACTION_INCOMING_NOTIFICATION_TO_VOICE_MESSAGE_BODY_FORMAT"
    }

    @objc
    static public var incomingReactionAudioMessageFormat: String {
        "REACTION_INCOMING_NOTIFICATION_TO_AUDIO_BODY_FORMAT"
    }

    @objc
    static public var incomingReactionGifMessageFormat: String {
        "REACTION_INCOMING_NOTIFICATION_TO_GIF_BODY_FORMAT"
    }

    @objc
    static public var incomingReactionFileMessageFormat: String {
        "REACTION_INCOMING_NOTIFICATION_TO_FILE_BODY_FORMAT"
    }
}

// MARK: -

@objc
public class CallStrings: NSObject {
    @objc
    static public var callStatusFormat: String {
        "CALL_STATUS_FORMAT"
    }

    @objc
    static public var confirmAndCallButtonTitle: String {
        "SAFETY_NUMBER_CHANGED_CONFIRM_CALL_ACTION"
    }

    @objc
    static public var callBackAlertTitle: String {
        "CALL_USER_ALERT_TITLE"
    }
    @objc
    static public var callBackAlertMessageFormat: String {
        "CALL_USER_ALERT_MESSAGE_FORMAT"
    }
    @objc
    static public var callBackAlertCallButton: String {
        "CALL_USER_ALERT_CALL_BUTTON"
    }

    // MARK: - Notification actions

    @objc
    static public var callBackButtonTitle: String {
        "CALLBACK_BUTTON_TITLE"
    }
    @objc
    static public var showThreadButtonTitle: String {
        "SHOW_THREAD_BUTTON_TITLE"
    }
    @objc
    static public var answerCallButtonTitle: String {
        "ANSWER_CALL_BUTTON_TITLE"
    }
    @objc
    static public var declineCallButtonTitle: String {
        "REJECT_CALL_BUTTON_TITLE"
    }
}

// MARK: -

@objc
public class MediaStrings: NSObject {
    @objc
    static public var allMedia: String {
        "MEDIA_DETAIL_VIEW_ALL_MEDIA_BUTTON"
    }
}

// MARK: -

@objc
public class SafetyNumberStrings: NSObject {
    @objc
    static public var confirmSendButton: String {
        "SAFETY_NUMBER_CHANGED_CONFIRM_SEND_ACTION"
    }
}

// MARK: -

@objc
public class MegaphoneStrings: NSObject {
    @objc
    static public var remindMeLater: String {
        "MEGAPHONE_REMIND_LATER"
    }

    @objc
    static public var weWillRemindYouLater: String {
        "MEGAPHONE_WILL_REMIND_LATER"
    }
}
