//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation

public enum DeviceNameError: Error {
    case assertionFailure
    case invalidInput
    case cryptError(_ description: String)
}

@objc
public class DeviceNames: NSObject {
    // Never instantiate this class.
    private override init() {}

    private static let syntheticIVLength: UInt = 16

    @objc
    public class func encryptDeviceName(plaintext: String) throws -> Data {

        guard let plaintextData = plaintext.data(using: .utf8) else {
            owsFailDebug("Could not convert text to UTF-8.")
            throw DeviceNameError.invalidInput
        }

        return Data()
    }

    private class func computeSyntheticIV(masterSecret: Data,
                                          plaintextData: Data) throws -> Data {
        // synthetic_iv = HmacSHA256(key=HmacSHA256(key=master_secret, input=“auth”), input=plaintext)[0:16]
        guard let syntheticIVInput = "auth".data(using: .utf8) else {
            owsFailDebug("Could not convert text to UTF-8.")
            throw DeviceNameError.assertionFailure
        }
        guard let syntheticIVKey = Cryptography.computeSHA256HMAC(syntheticIVInput, key: masterSecret) else {
            owsFailDebug("Could not compute synthetic IV key.")
            throw DeviceNameError.assertionFailure
        }
        guard let syntheticIV = Cryptography.computeSHA256HMAC(plaintextData, key: syntheticIVKey, truncatedToBytes: syntheticIVLength) else {
            owsFailDebug("Could not compute synthetic IV.")
            throw DeviceNameError.assertionFailure
        }
        return syntheticIV
    }

    private class func computeCipherKey(masterSecret: Data,
                                        syntheticIV: Data) throws -> Data {
        // cipher_key = HmacSHA256(key=HmacSHA256(key=master_secret, “cipher”), input=synthetic_iv)
        guard let cipherKeyInput = "cipher".data(using: .utf8) else {
            owsFailDebug("Could not convert text to UTF-8.")
            throw DeviceNameError.assertionFailure
        }
        guard let cipherKeyKey = Cryptography.computeSHA256HMAC(cipherKeyInput, key: masterSecret) else {
            owsFailDebug("Could not compute cipher key key.")
            throw DeviceNameError.assertionFailure
        }
        guard let cipherKey = Cryptography.computeSHA256HMAC(syntheticIV, key: cipherKeyKey) else {
            owsFailDebug("Could not compute cipher key.")
            throw DeviceNameError.assertionFailure
        }
        return cipherKey
    }
}
