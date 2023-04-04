//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import CommonCrypto

public struct ProvisionMessage {
    public let aci: UUID?
    public let phoneNumber: String
    public let pni: UUID?
    public let profileKey: OWSAES256Key
    public let areReadReceiptsEnabled: Bool?
    public let primaryUserAgent: String?
    public let provisioningCode: String
    public let provisioningVersion: UInt32?
}

public enum ProvisioningError: Error {
    case invalidProvisionMessage(_ description: String)
}

public class ProvisioningCipher {
    internal class var messageInfo: String {
        return "TextSecure Provisioning Message"
    }
}
