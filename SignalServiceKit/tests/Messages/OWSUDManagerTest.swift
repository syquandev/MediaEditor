//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import XCTest
import Foundation
import Curve25519Kit
import SignalCoreKit
import LibSignalClient
@testable import SignalServiceKit

class OWSUDManagerTest: SSKBaseTestSwift {

    private var udManagerImpl: OWSUDManagerImpl {
        return SSKEnvironment.shared.udManager as! OWSUDManagerImpl
    }

    // MARK: - Setup/Teardown

    let aliceE164 = "+13213214321"
    let aliceUuid = UUID()
    let trustRoot = IdentityKeyPair.generate()
    lazy var aliceAddress = SignalServiceAddress(uuid: aliceUuid, phoneNumber: aliceE164)
    lazy var defaultSenderCert = buildSenderCertificate(uuidOnly: false)
    lazy var uuidOnlySenderCert = buildSenderCertificate(uuidOnly: true)

    override func setUp() {
        super.setUp()

        tsAccountManager.registerForTests(withLocalNumber: aliceE164, uuid: aliceUuid)

        // Configure UDManager
        self.write { transaction in
            self.profileManager.setProfileKeyData(OWSAES256Key.generateRandom().keyData,
                                                  for: self.aliceAddress,
                                                  userProfileWriter: .tests,
                                                  transaction: transaction)
        }

        udManagerImpl.trustRoot = ECPublicKey(trustRoot.publicKey)
        udManagerImpl.setSenderCertificate(uuidOnly: true, certificateData: Data(uuidOnlySenderCert.serialize()))
        udManagerImpl.setSenderCertificate(uuidOnly: false, certificateData: Data(defaultSenderCert.serialize()))
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    // MARK: - Tests

    func testMode_self() {
        XCTAssert(udManagerImpl.hasSenderCertificates())

        XCTAssert(tsAccountManager.isRegistered)
        guard let localAddress = tsAccountManager.localAddress else {
            XCTFail("localAddress was unexpectedly nil")
            return
        }
        XCTAssert(localAddress.isValid)

        do {
            let udAccess = udManagerImpl.udAccess(forAddress: localAddress, requireSyncAccess: false)!
            XCTAssertNotNil(udAccess)
            XCTAssertEqual(.enabled, udAccess.udAccessMode)
            XCTAssertFalse(udAccess.isRandomKey)
        }

        do {
            udManagerImpl.setUnidentifiedAccessMode(.unknown, address: aliceAddress)
            let udAccess = udManagerImpl.udAccess(forAddress: localAddress, requireSyncAccess: false)!
            XCTAssertNotNil(udAccess)
            XCTAssertEqual(.unknown, udAccess.udAccessMode)
            XCTAssertFalse(udAccess.isRandomKey)
        }

        do {
            udManagerImpl.setUnidentifiedAccessMode(.disabled, address: aliceAddress)
            let udAccess = udManagerImpl.udAccess(forAddress: localAddress, requireSyncAccess: false)
            XCTAssertNil(udAccess)
        }

        do {
            udManagerImpl.setUnidentifiedAccessMode(.enabled, address: aliceAddress)
            let udAccess = udManagerImpl.udAccess(forAddress: localAddress, requireSyncAccess: false)!
            XCTAssertNotNil(udAccess)
            XCTAssertEqual(.enabled, udAccess.udAccessMode)
            XCTAssertFalse(udAccess.isRandomKey)
        }

        do {
            udManagerImpl.setUnidentifiedAccessMode(.unrestricted, address: aliceAddress)
            let udAccess = udManagerImpl.udAccess(forAddress: localAddress, requireSyncAccess: false)!
            XCTAssertNotNil(udAccess)
            XCTAssertEqual(.unrestricted, udAccess.udAccessMode)
            XCTAssert(udAccess.isRandomKey)
        }
    }

    func testMode_noProfileKey() {
        XCTAssert(udManagerImpl.hasSenderCertificates())

        XCTAssert(tsAccountManager.isRegistered)
        guard let localAddress = tsAccountManager.localAddress else {
            XCTFail("localAddress was unexpectedly nil")
            return
        }
        XCTAssert(localAddress.isValid)

        // Ensure UD is enabled by setting our own access level to enabled.
        udManagerImpl.setUnidentifiedAccessMode(.enabled, address: localAddress)

        let bobRecipientAddress = SignalServiceAddress(phoneNumber: "+13213214322")
        XCTAssertFalse(bobRecipientAddress.isLocalAddress)
        self.read { transaction in
            XCTAssertNil(self.profileManager.profileKeyData(for: bobRecipientAddress, transaction: transaction))
        }

        do {
            let udAccess = udManagerImpl.udAccess(forAddress: bobRecipientAddress, requireSyncAccess: false)!
            XCTAssertNotNil(udAccess)
            XCTAssertEqual(.unknown, udAccess.udAccessMode)
            XCTAssert(udAccess.isRandomKey)
        }

        do {
            udManagerImpl.setUnidentifiedAccessMode(.unknown, address: bobRecipientAddress)
            let udAccess = udManagerImpl.udAccess(forAddress: bobRecipientAddress, requireSyncAccess: false)!
            XCTAssertNotNil(udAccess)
            XCTAssertEqual(.unknown, udAccess.udAccessMode)
            XCTAssert(udAccess.isRandomKey)
        }

        do {
            udManagerImpl.setUnidentifiedAccessMode(.disabled, address: bobRecipientAddress)
            let udAccess = udManagerImpl.udAccess(forAddress: bobRecipientAddress, requireSyncAccess: false)
            XCTAssertNil(udAccess)
        }

        do {
            udManagerImpl.setUnidentifiedAccessMode(.enabled, address: bobRecipientAddress)
            let udAccess = udManagerImpl.udAccess(forAddress: bobRecipientAddress, requireSyncAccess: false)
            XCTAssertNil(udAccess)
        }

        do {
            // Bob should work in unrestricted mode, even if he doesn't have a profile key.
            udManagerImpl.setUnidentifiedAccessMode(.unrestricted, address: bobRecipientAddress)
            let udAccess = udManagerImpl.udAccess(forAddress: bobRecipientAddress, requireSyncAccess: false)!
            XCTAssertNotNil(udAccess)
            XCTAssertEqual(.unrestricted, udAccess.udAccessMode)
            XCTAssert(udAccess.isRandomKey)
        }
    }

    func testMode_withProfileKey() {
        XCTAssert(udManagerImpl.hasSenderCertificates())

        XCTAssert(tsAccountManager.isRegistered)
        guard let localAddress = tsAccountManager.localAddress else {
            XCTFail("localAddress was unexpectedly nil")
            return
        }
        XCTAssert(localAddress.isValid)

        // Ensure UD is enabled by setting our own access level to enabled.
        udManagerImpl.setUnidentifiedAccessMode(.enabled, address: localAddress)

        let bobRecipientAddress = SignalServiceAddress(phoneNumber: "+13213214322")
        XCTAssertFalse(bobRecipientAddress.isLocalAddress)
        self.write { transaction in
            self.profileManager.setProfileKeyData(OWSAES256Key.generateRandom().keyData,
                                                  for: bobRecipientAddress,
                                                  userProfileWriter: .tests,
                                                  transaction: transaction)
        }

        do {
            let udAccess = udManagerImpl.udAccess(forAddress: bobRecipientAddress, requireSyncAccess: false)!
            XCTAssertNotNil(udAccess)
            XCTAssertEqual(.unknown, udAccess.udAccessMode)
            XCTAssertFalse(udAccess.isRandomKey)
        }

        do {
            udManagerImpl.setUnidentifiedAccessMode(.unknown, address: bobRecipientAddress)
            let udAccess = udManagerImpl.udAccess(forAddress: bobRecipientAddress, requireSyncAccess: false)!
            XCTAssertNotNil(udAccess)
            XCTAssertEqual(.unknown, udAccess.udAccessMode)
            XCTAssertFalse(udAccess.isRandomKey)

        }

        do {
            udManagerImpl.setUnidentifiedAccessMode(.disabled, address: bobRecipientAddress)
            let udAccess = udManagerImpl.udAccess(forAddress: bobRecipientAddress, requireSyncAccess: false)
            XCTAssertNil(udAccess)
        }

        do {
            udManagerImpl.setUnidentifiedAccessMode(.enabled, address: bobRecipientAddress)
            let udAccess = udManagerImpl.udAccess(forAddress: bobRecipientAddress, requireSyncAccess: false)!
            XCTAssertNotNil(udAccess)
            XCTAssertEqual(.enabled, udAccess.udAccessMode)
            XCTAssertFalse(udAccess.isRandomKey)
        }

        do {
            udManagerImpl.setUnidentifiedAccessMode(.unrestricted, address: bobRecipientAddress)
            let udAccess = udManagerImpl.udAccess(forAddress: bobRecipientAddress, requireSyncAccess: false)!
            XCTAssertNotNil(udAccess)
            XCTAssertEqual(.unrestricted, udAccess.udAccessMode)
            XCTAssert(udAccess.isRandomKey)
        }
    }

    func test_senderAccess() {
        XCTAssert(udManagerImpl.hasSenderCertificates())

        XCTAssert(tsAccountManager.isRegistered)
        guard let localAddress = tsAccountManager.localAddress else {
            XCTFail("localAddress was unexpectedly nil")
            return
        }
        XCTAssert(localAddress.isValid)

        // Ensure UD is enabled by setting our own access level to enabled.
        udManagerImpl.setUnidentifiedAccessMode(.enabled, address: localAddress)

        let bobRecipientAddress = SignalServiceAddress(phoneNumber: "+13213214322")
        XCTAssertFalse(bobRecipientAddress.isLocalAddress)
        write { transaction in
            self.profileManager.setProfileKeyData(OWSAES256Key.generateRandom().keyData,
                                                  for: bobRecipientAddress,
                                                  userProfileWriter: .tests,
                                                  transaction: transaction)
        }

        let completed = self.expectation(description: "completed")
        firstly {
            udManagerImpl.ensureSenderCertificates(certificateExpirationPolicy: .strict)
        }.done { senderCertificates in
            do {
                let sendingAccess = self.udManagerImpl.udSendingAccess(forAddress: bobRecipientAddress,
                                                                       requireSyncAccess: false,
                                                                       senderCertificates: senderCertificates)!
                XCTAssertEqual(.unknown, sendingAccess.udAccess.udAccessMode)
                XCTAssertFalse(sendingAccess.udAccess.isRandomKey)
                XCTAssertEqual(sendingAccess.senderCertificate.serialize(),
                               self.defaultSenderCert.serialize())
            }
        }.done {
            completed.fulfill()
        }
        self.wait(for: [completed], timeout: 1.0)
    }
    // MARK: - Util

    func buildSenderCertificate(uuidOnly: Bool) -> SenderCertificate {
        let serverKeys = IdentityKeyPair.generate()
        let serverCert = try! ServerCertificate(keyId: 1,
                                                publicKey: serverKeys.publicKey,
                                                trustRoot: trustRoot.privateKey)

        var senderAddress = try! SealedSenderAddress(e164: nil, uuidString: aliceUuid.uuidString, deviceId: 1)
        if !uuidOnly {
            senderAddress.e164 = aliceE164
        }

        let expires = NSDate.ows_millisecondTimeStamp() + kWeekInMs
        let senderKeys = IdentityKeyPair.generate()
        return try! SenderCertificate(sender: senderAddress,
                                      publicKey: senderKeys.publicKey,
                                      expiration: expires,
                                      signerCertificate: serverCert,
                                      signerKey: serverKeys.privateKey)
    }
}
