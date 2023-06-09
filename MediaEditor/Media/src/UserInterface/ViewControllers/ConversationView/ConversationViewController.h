//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_CLOSED_ENUM(NSUInteger, ConversationViewAction) {
    ConversationViewActionNone,
    ConversationViewActionCompose,
    ConversationViewActionAudioCall,
    ConversationViewActionVideoCall,
    ConversationViewActionGroupCallLobby,
    ConversationViewActionNewGroupActionSheet,
    ConversationViewActionUpdateDraft
};

NS_ASSUME_NONNULL_END
