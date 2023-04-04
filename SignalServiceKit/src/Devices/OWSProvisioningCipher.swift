//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import CommonCrypto

public class OWSProvisioningCipher: NSObject {
    // Local errors for logging purposes only.
    // FIXME: If we start propagating errors out of encrypt(_:), we'll want to revisit this.
    private enum Error: Swift.Error {
        case unexpectedLengthForInitializationVector
        case dataIsTooLongToEncrypt
        case encryptionFailed
        case macComputationFailed
    }

    private static let cipherKeyLength: Int = 32
    private static let macKeyLength: Int = 32

    private let theirPublicKeyData: Data
    private let initializationVector: Data

    @objc
    public convenience init(theirPublicKey: Data) {
        self.init(
            theirPublicKey: theirPublicKey,
            initializationVector: Cryptography.generateRandomBytes(UInt(kCCBlockSizeAES128)))
    }

    #if TESTABLE_BUILD
    @objc
    private convenience init(theirPublicKey: Data, initializationVector: Data) {
        self.init(
            theirPublicKey: theirPublicKey,
            ourKeyPair: ourKeyPair.identityKeyPair,
            initializationVector: initializationVector)
    }
    #endif

    private init(theirPublicKey: Data, initializationVector: Data) {
        self.theirPublicKeyData = theirPublicKey
        self.initializationVector = initializationVector
    }

    // FIXME: propagate errors from here instead of just returning nil.
    // This means auditing all of the places we throw OR deciding it's okay to throw arbitrary errors.
    @objc
    public func encrypt(_ data: Data) -> Data? {
        return Data()
    }

    private func encrypt(_ data: Data, key: ArraySlice<UInt8>) throws -> Data {
        guard initializationVector.count == kCCBlockSizeAES128 else {
            // FIXME: This can only occur during testing; should it be non-recoverable?
            throw Error.unexpectedLengthForInitializationVector
        }

        guard data.count < Int.max - (kCCBlockSizeAES128 + initializationVector.count) else {
            throw Error.dataIsTooLongToEncrypt
        }

        let ciphertextBufferSize = data.count + kCCBlockSizeAES128

        var ciphertextData = Data(count: ciphertextBufferSize)

        var bytesEncrypted = 0
        let cryptStatus: CCCryptorStatus = key.withUnsafeBytes { keyBytes in
            initializationVector.withUnsafeBytes { ivBytes in
                data.withUnsafeBytes { dataBytes in
                    ciphertextData.withUnsafeMutableBytes { ciphertextBytes in
                        let status = CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress, keyBytes.count,
                            ivBytes.baseAddress,
                            dataBytes.baseAddress, dataBytes.count,
                            ciphertextBytes.baseAddress, ciphertextBytes.count,
                            &bytesEncrypted)
                        return status
                    }
                }
            }
        }

        guard cryptStatus == kCCSuccess else {
            throw Error.encryptionFailed
        }

        // message format is (iv || ciphertext)
        return initializationVector + ciphertextData.prefix(bytesEncrypted)
    }

    private func mac(forMessage message: Data, key: ArraySlice<UInt8>) throws -> Data {
        guard let mac = Cryptography.computeSHA256HMAC(message, key: Data(key)) else {
            throw Error.macComputationFailed
        }
        return mac
    }
}
