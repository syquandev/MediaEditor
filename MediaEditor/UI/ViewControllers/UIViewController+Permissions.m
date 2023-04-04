//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "UIViewController+Permissions.h"
#import "UIUtil.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <SignalCoreKit/Threading.h>
#import <MediaEditor-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation UIViewController (Permissions)

- (void)ows_askForCameraPermissions:(void (^)(BOOL granted))callbackParam
{

    // Ensure callback is invoked on main thread.
    void (^callback)(BOOL) = ^(BOOL granted) { DispatchMainThreadSafe(^{ callbackParam(granted); }); };

    if (CurrentAppContext().reportedApplicationState == UIApplicationStateBackground) {
        callback(NO);
        return;
    }

    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusDenied) {
        ActionSheetController *alert = [[ActionSheetController alloc]
            initWithTitle:@"MISSING_CAMERA_PERMISSION_TITLE"
                  message:@"MISSING_CAMERA_PERMISSION_MESSAGE"];

        ActionSheetAction *_Nullable openSettingsAction =
            [AppContextUtils openSystemSettingsActionWithCompletion:^{ callback(NO); }];
        if (openSettingsAction != nil) {
            [alert addAction:openSettingsAction];
        }

        ActionSheetAction *dismissAction =
            [[ActionSheetAction alloc] initWithTitle:CommonStrings.dismissButton
                                               style:ActionSheetActionStyleCancel
                                             handler:^(ActionSheetAction *action) { callback(NO); }];
        [alert addAction:dismissAction];

        [self presentActionSheet:alert];
    } else if (status == AVAuthorizationStatusAuthorized) {
        callback(YES);
    } else if (status == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:callback];
    } else {
        callback(NO);
    }
}

- (void)ows_askForMediaLibraryPermissions:(void (^)(BOOL granted))callbackParam
{

    // Ensure callback is invoked on main thread.
    void (^completionCallback)(BOOL) = ^(BOOL granted) { DispatchMainThreadSafe(^{ callbackParam(granted); }); };

    void (^presentSettingsDialog)(void) = ^(void) {
        DispatchMainThreadSafe(^{
            ActionSheetController *alert = [[ActionSheetController alloc]
                initWithTitle:@"MISSING_MEDIA_LIBRARY_PERMISSION_TITLE"
                      message:@"MISSING_MEDIA_LIBRARY_PERMISSION_MESSAGE"];

            ActionSheetAction *_Nullable openSettingsAction =
                [AppContextUtils openSystemSettingsActionWithCompletion:^() { completionCallback(NO); }];
            if (openSettingsAction) {
                [alert addAction:openSettingsAction];
            }

            ActionSheetAction *dismissAction =
                [[ActionSheetAction alloc] initWithTitle:CommonStrings.dismissButton
                                                   style:ActionSheetActionStyleCancel
                                                 handler:^(ActionSheetAction *action) { completionCallback(NO); }];
            [alert addAction:dismissAction];

            [self presentActionSheet:alert];
        });
    };

    if (CurrentAppContext().reportedApplicationState == UIApplicationStateBackground) {
        completionCallback(NO);
        return;
    }

    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        completionCallback(NO);
    }

    // TODO Xcode 12: When we're compiling on in Xcode 12, adjust this to
    // use the new non-deprecated API that returns the "limited" status.
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];

    switch (status) {
        case PHAuthorizationStatusAuthorized: {
            completionCallback(YES);
            return;
        }
        case PHAuthorizationStatusDenied: {
            presentSettingsDialog();
            return;
        }
        case PHAuthorizationStatusNotDetermined: {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus newStatus) {
                if (newStatus == PHAuthorizationStatusAuthorized) {
                    completionCallback(YES);
                } else {
                    presentSettingsDialog();
                }
            }];
            return;
        }
        case PHAuthorizationStatusRestricted: {
            // when does this happen?
            return;
        }
        case PHAuthorizationStatusLimited: {
            completionCallback(YES);
            return;
        }
    }
}

- (void)ows_askForMicrophonePermissions:(void (^)(BOOL granted))callbackParam
{

    // Ensure callback is invoked on main thread.
    void (^callback)(BOOL) = ^(BOOL granted) { DispatchMainThreadSafe(^{ callbackParam(granted); }); };

    // We want to avoid asking for audio permission while the app is in the background,
    // as WebRTC can ask at some strange times. However, if we're currently in a call
    // it's important we allow you to request audio permission regardless of app state.
    if (CurrentAppContext().reportedApplicationState == UIApplicationStateBackground
        && !CurrentAppContext().hasActiveCall) {
        callback(NO);
        return;
    }

    [[AVAudioSession sharedInstance] requestRecordPermission:callback];
}

- (void)ows_showNoMicrophonePermissionActionSheet
{
    DispatchMainThreadSafe(^{
        ActionSheetController *alert = [[ActionSheetController alloc]
            initWithTitle:@"CALL_AUDIO_PERMISSION_TITLE"
                  message:@"CALL_AUDIO_PERMISSION_MESSAGE"];

        ActionSheetAction *_Nullable openSettingsAction = [AppContextUtils openSystemSettingsActionWithCompletion:nil];
        if (openSettingsAction) {
            [alert addAction:openSettingsAction];
        }

        [alert addAction:OWSActionSheets.dismissAction];

        [self presentActionSheet:alert];
    });
}

@end

NS_ASSUME_NONNULL_END
