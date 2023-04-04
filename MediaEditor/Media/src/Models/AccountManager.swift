//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalServiceKit
import SignalCoreKit

public enum AccountManagerError: Error {
    case reregistrationDifferentAccount
}

// MARK: -

/**
 * Signal is actually two services - textSecure for messages and red phone (for calls). 
 * AccountManager delegates to both.
 */
@objc
public class AccountManager: NSObject {

    @objc
    public override init() {
        super.init()

        SwiftSingletons.register(self)
    }

    // MARK: registration

    @objc
    func requestRegistrationVerificationObjC(e164: String, captchaToken: String?, isSMS: Bool) -> AnyPromise {
        return AnyPromise(requestRegistrationVerification(e164: e164, captchaToken: captchaToken, isSMS: isSMS))
    }

    func requestRegistrationVerification(e164: String, captchaToken: String?, isSMS: Bool) -> Promise<Void> {
        requestAccountVerification(e164: e164,
                                   captchaToken: captchaToken,
                                   isSMS: isSMS,
                                   mode: .registration)
    }

    public enum VerificationMode {
        case registration
        case changePhoneNumber
    }

    public func requestAccountVerification(e164: String,
                                           captchaToken: String?,
                                           isSMS: Bool,
                                           mode: VerificationMode) -> Promise<Void> {
        return Promise.value(())
    }

    func getPreauthChallenge(e164: String) -> Promise<String?> {
        return Promise.value(nil)
    }

    func requestChangePhoneNumber(newPhoneNumber: String, verificationCode: String, registrationLock: String?) -> Promise<Void> {
        guard let verificationCode = verificationCode.nilIfEmpty else {
            let error = OWSError(error: .userError,
                                 description: NSLocalizedString("REGISTRATION_ERROR_BLANK_VERIFICATION_CODE",
                                                                comment: "alert body during registration"),
                                 isRetryable: false)
            return Promise(error: error)
        }

        Logger.info("Changing phone number.")

        // Mark a change as in flight.  If the change is interrupted,
        // we'll use /whoami on next app launch to ensure local client
        // state reflects current service state.
        let changeToken = Self.databaseStorage.write { transaction in
            ChangePhoneNumber.changeWillBegin(transaction: transaction)
        }

        return Promise.value(())
    }

    private struct RegistrationResponse {
        var aci: UUID
        var pni: UUID
        var hasPreviouslyUsedKBS = false
    }

    private func registerForTextSecure(verificationCode: String, pin: String?, checkForAvailableTransfer: Bool) -> Promise<RegistrationResponse> {
        let serverAuthToken = generateServerAuthToken()

        return Promise<Any?> { future in
            

        }.map(on: .global()) { responseObject throws -> RegistrationResponse in
            self.databaseStorage.write { transaction in
            }

            guard let responseObject = responseObject else {
                throw OWSAssertionError("Missing responseObject.")
            }

            guard let params = ParamParser(responseObject: responseObject) else {
                throw OWSAssertionError("Missing or invalid params.")
            }

            let aci: UUID = try params.required(key: "uuid")
            let pni: UUID = try params.required(key: "pni")
            let hasPreviouslyUsedKBS = try params.optional(key: "storageCapable") ?? false

            return RegistrationResponse(aci: aci, pni: pni, hasPreviouslyUsedKBS: hasPreviouslyUsedKBS)
        }
    }

    @objc
    public func fakeRegistration() {
        fakeRegisterForTests(phoneNumber: "+15551231234", uuid: UUID())
        SignalApp.shared().showConversationSplitView()
    }

    private func fakeRegisterForTests(phoneNumber: String, uuid: UUID) {
        
        completeRegistration()
    }

    private func createPreKeys() -> Promise<Void> {
        return Promise.value(())
    }

    private func completeRegistration() {
        Logger.info("")
    }

    // MARK: Message Delivery

    func updatePushTokens(pushToken: String, voipToken: String?) -> Promise<Void> {
        return Promise.value(())
    }

    func recordUuidIfNecessary() {
        DispatchQueue.global().async {
            _ = self.ensureUuid().catch { error in
                // Until we're in a UUID-only world, don't require a
                // local UUID.
                owsFailDebug("error: \(error)")
            }
        }
    }

    func ensureUuid() -> Promise<UUID> {
        return Promise.value(UUID(uuidString: "sss")!)
    }

    private func generateServerAuthToken() -> String {
        return Cryptography.generateRandomBytes(16).hexadecimalString
    }
}
