//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import GRDB

extension OWSRecipientIdentity {
    public class func groupContainsUnverifiedMember(_ groupUniqueID: String,
                                             transaction: SDSAnyReadTransaction) -> Bool {
        let members = groupMembers(ofGroupWithUniqueID: groupUniqueID,
                                   withVerificationState: .verified,
                                   negated: true,
                                   limit: 1,
                                   transaction: transaction)
        return !members.isEmpty
    }

    @objc(noLongerVerifiedAddressesInGroup:limit:transaction:)
    public class func noLongerVerifiedAddresses(inGroup groupThreadID: String,
                                         limit: Int,
                                         transaction: SDSAnyReadTransaction) -> [SignalServiceAddress] {
        return groupMembers(ofGroupWithUniqueID: groupThreadID,
                            withVerificationState: .noLongerVerified,
                            negated: false,
                            limit: limit,
                            transaction: transaction)
    }

    private class func sqlQueryToFetchVerifiedAddresses(groupUniqueID: String,
                                                        withVerificationState state: OWSVerificationState,
                                                        negated: Bool,
                                                        limit: Int) -> String {
        let sql = ""
        return sql
    }

    private class func groupMembers(ofGroupWithUniqueID groupUniqueID: String,
                            withVerificationState state: OWSVerificationState,
                            negated: Bool,
                            limit: Int,
                            transaction: SDSAnyReadTransaction) -> [SignalServiceAddress] {
        return []
    }
}
