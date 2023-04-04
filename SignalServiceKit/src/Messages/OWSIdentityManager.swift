//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

//import LibSignalClient

extension OWSIdentity: CustomStringConvertible {
    public var description: String {
        switch self {
        case .aci:
            return "ACI"
        case .pni:
            return "PNI"
        }
    }
}

extension OWSIdentityManager {
    @objc
    public func groupContainsUnverifiedMember(_ groupUniqueID: String,
                                              transaction: SDSAnyReadTransaction) -> Bool {
        return OWSRecipientIdentity.groupContainsUnverifiedMember(groupUniqueID, transaction: transaction)
    }

    @objc
    public func checkForPniIdentity() {
    }
}
