//
//  VirgilAuthorizer.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/25/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilCrypto
import VirgilSDK

public class VirgilAuthorizer {
    public let crypto: VirgilCrypto
    public let cardCrypto: VirgilCardCrypto
    public let verifier: VirgilCardVerifier
    public let client: Client

    public enum VirgilAuthorizerError: Error {
        case cardVerifierInitFailed
    }

    public init() throws {
        self.crypto = try VirgilCrypto()
        self.cardCrypto = VirgilCardCrypto(virgilCrypto: crypto)
        self.client = Client(crypto: crypto, cardCrypto: self.cardCrypto)

        guard let verifier = VirgilCardVerifier(cardCrypto: self.cardCrypto) else {
            throw VirgilAuthorizerError.cardVerifierInitFailed
        }

        self.verifier = verifier
    }

    public func signIn(identity: String) throws {
        let localKeyManager = try LocalKeyManager(identity: identity, crypto: self.crypto)

        guard try localKeyManager.exists() else {
            throw UserFriendlyError.noUserOnDevice
        }

        try VirgilHelper.initialize(identity: identity)
    }

    public func signUp(identity: String) throws {
        let localKeyManager = try LocalKeyManager(identity: identity, crypto: self.crypto)

        guard try !localKeyManager.exists() else {
            throw UserFriendlyError.usernameAlreadyUsed
        }

        let keyPair = try self.crypto.generateKeyPair()

        let card = try self.client.signUp(identity: identity, keyPair: keyPair, verifier: self.verifier)

        let user = UserData(keyPair: keyPair, card: card)
        try localKeyManager.store(user)

        try VirgilHelper.initialize(identity: identity)
    }

    public func logOut(identity: String) {
        let localKeyManager = try? LocalKeyManager(identity: identity, crypto: self.crypto)

        try? localKeyManager?.delete()
    }
}
