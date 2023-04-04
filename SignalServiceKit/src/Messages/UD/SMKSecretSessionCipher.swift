//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalCoreKit

public struct SecretSessionKnownSenderError: Error {
    public let senderAddress: SignalServiceAddress
    public let senderDeviceId: UInt32
    public let groupId: Data?
    public let unsealedContent: Data
    public let underlyingError: Error

//    init(underlyingError: Error) {
//        self.underlyingError = underlyingError
//    }
}

@objc
public enum SMKSecretSessionCipherError: Int, Error {
    case selfSentMessage
    case invalidCertificate
}

// MARK: -

private class SMKSecretKeySpec: NSObject {

    @objc public let keyData: Data
    @objc public let algorithm: String

    init(keyData: Data, algorithm: String) {
        self.keyData = keyData
        self.algorithm = algorithm
    }
}

// MARK: -

@objc public enum SMKMessageType: Int {
    case whisper
    case prekey
    case senderKey
    case plaintext
}

@objc
public class SMKDecryptResult: NSObject {

    @objc public let senderAddress: SignalServiceAddress
    @objc public let senderDeviceId: Int
    @objc public let paddedPayload: Data
    @objc public let messageType: SMKMessageType

    init(senderAddress: SignalServiceAddress,
         senderDeviceId: Int,
         paddedPayload: Data,
         messageType: SMKMessageType) {
        self.senderAddress = senderAddress
        self.senderDeviceId = senderDeviceId
        self.paddedPayload = paddedPayload
        self.messageType = messageType
    }
}

@objc public class SMKSecretSessionCipher: NSObject {

    private let kUDPrefixString = "UnidentifiedDelivery"

    private let kSMKSecretSessionCipherMacLength: UInt = 10


    // MARK: - Public

    public func encryptMessage(
        recipient: SignalServiceAddress,
        deviceId: Int32,
        paddedPlaintext: Data,
        groupId: Data?
    ) throws -> Data {

        guard deviceId > 0 else {
            throw SMKError.assertionError(description: "\(logTag) invalid deviceId")
        }

        return Data()
    }
}
