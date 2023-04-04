//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation

@objc
public class AppContextUtils: NSObject {

    @objc
    public static func openSystemSettingsAction(completion: (() -> Void)?) -> ActionSheetAction? {

        return ActionSheetAction(title: CommonStrings.openSettingsButton,
                                 accessibilityIdentifier: "system_settings",
                                 style: .default) { _ in
        }
    }
}
