//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation

// MARK: - NSObject

@objc
public extension NSObject {
    final var preferences: OWSPreferences {
        Environment.shared.preferencesRef
    }

    static var preferences: OWSPreferences {
        Environment.shared.preferencesRef
    }
}

// MARK: - Obj-C Dependencies

public extension Dependencies {
    var preferences: OWSPreferences {
        Environment.shared.preferencesRef
    }

    static var preferences: OWSPreferences {
        Environment.shared.preferencesRef
    }
}

// MARK: - Swift-only Dependencies

public extension NSObject {
}

// MARK: - Swift-only Dependencies

public extension Dependencies {
}
