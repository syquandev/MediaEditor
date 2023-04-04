//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import ObjectiveC

extension NSError {

    @objc
    public var hasIsRetryable: Bool { hasIsRetryableImpl }

    @objc
    public var isRetryable: Bool { isRetryableImpl }
}

// MARK: -

extension Error {
    public var hasIsRetryable: Bool { (self as NSError).hasIsRetryable }

    public var isRetryable: Bool { (self as NSError).isRetryableImpl }
}

// MARK: -

extension NSError {

    fileprivate var hasIsRetryableImpl: Bool {
        if self is IsRetryableProvider {
            return true
        }
        return false
    }

    fileprivate var isRetryableImpl: Bool {
        if let error = self as? IsRetryableProvider {
            return error.isRetryableProvider
        }
        if let error = (self as Error) as? IsRetryableProvider {
            return error.isRetryableProvider
        }
        if CurrentAppContext().isRunningTests {
            Logger.warn("Error without retry behavior specified: \(self)")
        } else {
            owsFailDebug("Error without retry behavior specified: \(self)")
        }
        return true
    }
}

// MARK: -

public protocol IsRetryableProvider {
    var isRetryableProvider: Bool { get }
}

// MARK: -

extension OWSAssertionError: IsRetryableProvider {
    public var isRetryableProvider: Bool { false }
}

extension OWSGenericError: IsRetryableProvider {
    public var isRetryableProvider: Bool { false }
}

// MARK: -

// NOTE: We typically prefer to use a more specific error.
@objc
public class OWSRetryableError: NSObject, CustomNSError, IsRetryableProvider {
    @objc
    public static var asNSError: NSError {
        OWSRetryableError() as Error as NSError
    }

    // MARK: - IsRetryableProvider

    public var isRetryableProvider: Bool { true }
}

// MARK: -

// NOTE: We typically prefer to use a more specific error.
@objc
public class OWSUnretryableError: NSObject, CustomNSError, IsRetryableProvider {
    @objc
    public static var asNSError: NSError {
        OWSUnretryableError() as Error as NSError
    }

    // MARK: - IsRetryableProvider

    public var isRetryableProvider: Bool { false }
}

// MARK: -

public enum SSKUnretryableError: Error, IsRetryableProvider {
    case paymentsReconciliationFailure
    case paymentsProcessingFailure
    case partialLocalProfileFetch
    case stickerDecryptionFailure
    case stickerMissingFile
    case stickerOversizeFile
    case downloadCouldNotMoveFile
    case downloadCouldNotDeleteFile
    case invalidThread
    case messageProcessingFailed
    case couldNotLoadFileData
    case restoreGroupFailed

    // MARK: - IsRetryableProvider

    public var isRetryableProvider: Bool { false }
}
