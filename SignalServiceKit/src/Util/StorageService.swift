//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation

@objc
public protocol StorageServiceManagerProtocol {
    func recordPendingDeletions(deletedAddresses: [SignalServiceAddress])
    func recordPendingDeletions(deletedGroupV1Ids: [Data])
    func recordPendingDeletions(deletedGroupV2MasterKeys: [Data])

    func recordPendingUpdates(updatedAddresses: [SignalServiceAddress])
    func recordPendingUpdates(updatedGroupV1Ids: [Data])
    func recordPendingUpdates(updatedGroupV2MasterKeys: [Data])
    // A convenience method that calls recordPendingUpdates(updatedGroupV1Ids:)
    // or recordPendingUpdates(updatedGroupV2MasterKeys:).
    func recordPendingUpdates(groupModel: TSGroupModel)

    func recordPendingLocalAccountUpdates()

    func backupPendingChanges()

    @discardableResult
    func restoreOrCreateManifestIfNecessary() -> AnyPromise

    func resetLocalData(transaction: SDSAnyWriteTransaction)
}

// MARK: -

public struct StorageService: Dependencies {
    public enum StorageError: Error, IsRetryableProvider {
        case assertion
        case retryableAssertion
        case manifestDecryptionFailed(version: UInt64)
        case networkError(statusCode: Int, underlyingError: Error)
        case accountMissing

        // MARK: 

        public var isRetryableProvider: Bool {
            switch self {
            case .assertion:
                return false
            case .retryableAssertion:
                return true
            case .manifestDecryptionFailed:
                return false
            case .networkError(let statusCode, _):
                // If this is a server error, retry
                return statusCode >= 500
            case .accountMissing:
                return false
            }
        }

        public var errorUserInfo: [String: Any] {
            var userInfo: [String: Any] = [:]
            if case .networkError(_, let underlyingError) = self {
                userInfo[NSUnderlyingErrorKey] = underlyingError
            }
            return userInfo
        }
    }

    // MARK: - Storage Requests

    private struct StorageResponse {
        enum Status {
            case success
            case conflict
            case notFound
            case noContent
        }
        let status: Status
        let data: Data
    }
}
