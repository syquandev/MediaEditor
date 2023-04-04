//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "BlockListUIUtils.h"
#import <SignalServiceKit/TSContactThread.h>
#import <SignalServiceKit/TSGroupThread.h>
#import <MediaEditor-Swift.h>
#import <SignalCoreKit/SignalCoreKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^BlockAlertCompletionBlock)(ActionSheetAction *action);

@implementation BlockListUIUtils

#pragma mark - Block

+ (void)showBlockThreadActionSheet:(TSThread *)thread
                fromViewController:(UIViewController *)fromViewController
                   completionBlock:(nullable BlockActionCompletionBlock)completionBlock
{
    if ([thread isKindOfClass:[TSContactThread class]]) {
        TSContactThread *contactThread = (TSContactThread *)thread;
        [self showBlockAddressActionSheet:contactThread.contactAddress
                       fromViewController:fromViewController
                          completionBlock:completionBlock];
    } else if ([thread isKindOfClass:[TSGroupThread class]]) {
        TSGroupThread *groupThread = (TSGroupThread *)thread;
        [self showBlockGroupActionSheet:groupThread
                     fromViewController:fromViewController
                        completionBlock:completionBlock];
    }
}

+ (void)showBlockAddressActionSheet:(SignalServiceAddress *)address
                 fromViewController:(UIViewController *)fromViewController
                    completionBlock:(nullable BlockActionCompletionBlock)completionBlock
{
    NSString *displayName = @"";
    [self showBlockAddressesActionSheet:@[ address ]
                            displayName:displayName
                     fromViewController:fromViewController
                        completionBlock:completionBlock];
}

+ (void)showBlockSignalAccountActionSheet:(SignalAccount *)signalAccount
                       fromViewController:(UIViewController *)fromViewController
                          completionBlock:(nullable BlockActionCompletionBlock)completionBlock
{
    
}

+ (void)showBlockAddressesActionSheet:(NSArray<SignalServiceAddress *> *)addresses
                          displayName:(NSString *)displayName
                   fromViewController:(UIViewController *)fromViewController
                      completionBlock:(nullable BlockActionCompletionBlock)completionBlock
{

    NSString *title = [NSString stringWithFormat:@"BLOCK_LIST_BLOCK_USER_TITLE_FORMAT",
                                [self formatDisplayNameForAlertTitle:displayName]];

    ActionSheetController *actionSheet = [[ActionSheetController alloc]
        initWithTitle:title
              message:@"BLOCK_USER_BEHAVIOR_EXPLANATION"];

    ActionSheetAction *blockAction = [[ActionSheetAction alloc]
                  initWithTitle:@"BLOCK_LIST_BLOCK_BUTTON"
        accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"block")
                          style:ActionSheetActionStyleDestructive
                        handler:^(ActionSheetAction *_Nonnull action) {
                            [self blockAddresses:addresses
                                       displayName:displayName
                                fromViewController:fromViewController
                                   completionBlock:^(ActionSheetAction *ignore) {
                                       if (completionBlock) {
                                           completionBlock(YES);
                                       }
                                   }];
                        }];
    [actionSheet addAction:blockAction];

    ActionSheetAction *dismissAction =
        [[ActionSheetAction alloc] initWithTitle:CommonStrings.cancelButton
                         accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"dismiss")
                                           style:ActionSheetActionStyleCancel
                                         handler:^(ActionSheetAction *_Nonnull action) {
                                             if (completionBlock) {
                                                 completionBlock(NO);
                                             }
                                         }];
    [actionSheet addAction:dismissAction];
    [fromViewController presentActionSheet:actionSheet];
}

+ (void)showBlockGroupActionSheet:(TSGroupThread *)groupThread
               fromViewController:(UIViewController *)fromViewController
                  completionBlock:(nullable BlockActionCompletionBlock)completionBlock
{

    NSString *title = [NSString
        stringWithFormat:@"BLOCK_LIST_BLOCK_GROUP_TITLE_FORMAT",
        [self formatDisplayNameForAlertTitle:groupThread.groupNameOrDefault]];

    ActionSheetController *actionSheet =
        [[ActionSheetController alloc] initWithTitle:title
                                             message:@"BLOCK_GROUP_BEHAVIOR_EXPLANATION"];

    ActionSheetAction *blockAction = [[ActionSheetAction alloc]
                  initWithTitle:@"BLOCK_LIST_BLOCK_BUTTON"
        accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"block")
                          style:ActionSheetActionStyleDestructive
                        handler:^(ActionSheetAction *_Nonnull action) {
                            [self blockGroup:groupThread
                                fromViewController:fromViewController
                                   completionBlock:^(ActionSheetAction *ignore) {
                                       if (completionBlock) {
                                           completionBlock(YES);
                                       }
                                   }];
                        }];
    [actionSheet addAction:blockAction];

    ActionSheetAction *dismissAction =
        [[ActionSheetAction alloc] initWithTitle:CommonStrings.cancelButton
                         accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"dismiss")
                                           style:ActionSheetActionStyleCancel
                                         handler:^(ActionSheetAction *_Nonnull action) {
                                             if (completionBlock) {
                                                 completionBlock(NO);
                                             }
                                         }];
    [actionSheet addAction:dismissAction];
    [fromViewController presentActionSheet:actionSheet];
}

+ (void)blockAddresses:(NSArray<SignalServiceAddress *> *)addresses
           displayName:(NSString *)displayName
    fromViewController:(UIViewController *)fromViewController
       completionBlock:(BlockAlertCompletionBlock)completionBlock
{


    [self showOkAlertWithTitle:@"BLOCK_LIST_VIEW_BLOCKED_ALERT_TITLE"
                       message:[NSString
                                   stringWithFormat:@"BLOCK_LIST_VIEW_BLOCKED_ALERT_MESSAGE_FORMAT",
                                   [self formatDisplayNameForAlertMessage:displayName]]
            fromViewController:fromViewController
               completionBlock:completionBlock];
}

+ (void)blockGroup:(TSGroupThread *)groupThread
    fromViewController:(UIViewController *)fromViewController
       completionBlock:(BlockAlertCompletionBlock)completionBlock
{
}

+ (void)blockGroupStep2:(TSGroupThread *)groupThread
     fromViewController:(UIViewController *)fromViewController
        completionBlock:(BlockAlertCompletionBlock)completionBlock
{

    // block the group regardless of the ability to deliver the
    // "leave group" message.
    NSString *alertTitle
        = @"BLOCK_LIST_VIEW_BLOCKED_GROUP_ALERT_TITLE";
    NSString *alertBodyFormat = @"BLOCK_LIST_VIEW_BLOCKED_ALERT_MESSAGE_FORMAT";
    NSString *alertBody = [NSString
        stringWithFormat:alertBodyFormat, [self formatDisplayNameForAlertMessage:groupThread.groupNameOrDefault]];

    [self showOkAlertWithTitle:alertTitle
                       message:alertBody
            fromViewController:fromViewController
               completionBlock:completionBlock];
}

#pragma mark - Unblock

+ (void)showUnblockThreadActionSheet:(TSThread *)thread
                  fromViewController:(UIViewController *)fromViewController
                     completionBlock:(nullable BlockActionCompletionBlock)completionBlock
{
    if ([thread isKindOfClass:[TSContactThread class]]) {
        TSContactThread *contactThread = (TSContactThread *)thread;
        [self showUnblockAddressActionSheet:contactThread.contactAddress
                         fromViewController:fromViewController
                            completionBlock:completionBlock];
    } else if ([thread isKindOfClass:[TSGroupThread class]]) {
        TSGroupThread *groupThread = (TSGroupThread *)thread;
        [self showUnblockGroupActionSheet:groupThread.groupModel
                       fromViewController:fromViewController
                          completionBlock:completionBlock];
    }
}

+ (void)showUnblockAddressActionSheet:(SignalServiceAddress *)address
                   fromViewController:(UIViewController *)fromViewController
                      completionBlock:(nullable BlockActionCompletionBlock)completionBlock
{
    NSString *displayName = @"";
    [self showUnblockAddressesActionSheet:@[ address ]
                              displayName:displayName
                       fromViewController:fromViewController
                          completionBlock:completionBlock];
}

+ (void)showUnblockSignalAccountActionSheet:(SignalAccount *)signalAccount
                         fromViewController:(UIViewController *)fromViewController
                            completionBlock:(nullable BlockActionCompletionBlock)completionBlock
{
   
}

+ (void)showUnblockAddressesActionSheet:(NSArray<SignalServiceAddress *> *)addresses
                            displayName:(NSString *)displayName
                     fromViewController:(UIViewController *)fromViewController
                        completionBlock:(nullable BlockActionCompletionBlock)completionBlock
{

    NSString *title = [NSString
        stringWithFormat:
                           @"BLOCK_LIST_UNBLOCK_TITLE_FORMAT",
        [self formatDisplayNameForAlertTitle:displayName]];

    ActionSheetController *actionSheet = [[ActionSheetController alloc] initWithTitle:title message:nil];

    ActionSheetAction *unblockAction =
    [[ActionSheetAction alloc] initWithTitle:@"BLOCK_LIST_UNBLOCK_BUTTON"
                         accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"unblock")
                                           style:ActionSheetActionStyleDestructive
                                         handler:^(ActionSheetAction *_Nonnull action) {
                                             [BlockListUIUtils unblockAddresses:addresses
                                                                    displayName:displayName
                                                             fromViewController:fromViewController
                                                                completionBlock:^(ActionSheetAction *ignore) {
                                                                    if (completionBlock) {
                                                                        completionBlock(NO);
                                                                    }
                                                                }];
                                         }];
    [actionSheet addAction:unblockAction];

    ActionSheetAction *dismissAction =
        [[ActionSheetAction alloc] initWithTitle:CommonStrings.cancelButton
                         accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"dismiss")
                                           style:ActionSheetActionStyleCancel
                                         handler:^(ActionSheetAction *_Nonnull action) {
                                             if (completionBlock) {
                                                 completionBlock(YES);
                                             }
                                         }];
    [actionSheet addAction:dismissAction];
    [fromViewController presentActionSheet:actionSheet];
}

+ (void)unblockAddresses:(NSArray<SignalServiceAddress *> *)addresses
             displayName:(NSString *)displayName
      fromViewController:(UIViewController *)fromViewController
         completionBlock:(BlockAlertCompletionBlock)completionBlock
{
    NSString *titleFormat = @"BLOCK_LIST_VIEW_UNBLOCKED_ALERT_TITLE_FORMAT";
    NSString *title = [NSString stringWithFormat:titleFormat, [self formatDisplayNameForAlertMessage:displayName]];

    [self showOkAlertWithTitle:title message:nil fromViewController:fromViewController completionBlock:completionBlock];
}

+ (void)showUnblockGroupActionSheet:(TSGroupModel *)groupModel
                 fromViewController:(UIViewController *)fromViewController
                    completionBlock:(nullable BlockActionCompletionBlock)completionBlock
{

    NSString *title =
        [NSString stringWithFormat:@"BLOCK_LIST_UNBLOCK_GROUP_TITLE"];

    NSString *message = @"BLOCK_LIST_UNBLOCK_GROUP_BODY";

    ActionSheetController *actionSheet = [[ActionSheetController alloc] initWithTitle:title message:message];

    ActionSheetAction *unblockAction =
        [[ActionSheetAction alloc] initWithTitle: @"BLOCK_LIST_UNBLOCK_BUTTON"
                         accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"unblock")
                                           style:ActionSheetActionStyleDestructive
                                         handler:^(ActionSheetAction *_Nonnull action) {
                                             [BlockListUIUtils unblockGroup:groupModel
                                                         fromViewController:fromViewController
                                                            completionBlock:^(ActionSheetAction *ignore) {
                                                                if (completionBlock) {
                                                                    completionBlock(NO);
                                                                }
                                                            }];
                                         }];
    [actionSheet addAction:unblockAction];

    ActionSheetAction *dismissAction =
        [[ActionSheetAction alloc] initWithTitle:CommonStrings.cancelButton
                         accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"dismiss")
                                           style:ActionSheetActionStyleCancel
                                         handler:^(ActionSheetAction *_Nonnull action) {
                                             if (completionBlock) {
                                                 completionBlock(YES);
                                             }
                                         }];
    [actionSheet addAction:dismissAction];
    [fromViewController presentActionSheet:actionSheet];
}

+ (void)unblockGroup:(TSGroupModel *)groupModel
    fromViewController:(UIViewController *)fromViewController
       completionBlock:(BlockAlertCompletionBlock)completionBlock
{


    NSString *titleFormat = @"BLOCK_LIST_VIEW_UNBLOCKED_ALERT_TITLE_FORMAT";
    NSString *title =
        [NSString stringWithFormat:titleFormat, [self formatDisplayNameForAlertMessage:groupModel.groupNameOrDefault]];

    NSString *message
        = @"BLOCK_LIST_VIEW_UNBLOCKED_GROUP_ALERT_BODY";
    [self showOkAlertWithTitle:title
                       message:message
            fromViewController:fromViewController
               completionBlock:completionBlock];
}

#pragma mark - UI

+ (void)showOkAlertWithTitle:(NSString *)title
                     message:(nullable NSString *)message
          fromViewController:(UIViewController *)fromViewController
             completionBlock:(BlockAlertCompletionBlock)completionBlock
{

    ActionSheetController *alert = [[ActionSheetController alloc] initWithTitle:title message:message];

    ActionSheetAction *okAction =
        [[ActionSheetAction alloc] initWithTitle:CommonStrings.okButton
                         accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"ok")
                                           style:ActionSheetActionStyleDefault
                                         handler:completionBlock];
    [alert addAction:okAction];
    [fromViewController presentActionSheet:alert];
}

+ (NSString *)formatDisplayNameForAlertTitle:(NSString *)displayName
{
    return [self formatDisplayName:displayName withMaxLength:20];
}

+ (NSString *)formatDisplayNameForAlertMessage:(NSString *)displayName
{
    return [self formatDisplayName:displayName withMaxLength:127];
}

+ (NSString *)formatDisplayName:(NSString *)displayName withMaxLength:(NSUInteger)maxLength
{

    if (displayName.length > maxLength) {
        return [[displayName substringToIndex:maxLength] stringByAppendingString:@"…"];
    }

    return displayName;
}

@end

NS_ASSUME_NONNULL_END
