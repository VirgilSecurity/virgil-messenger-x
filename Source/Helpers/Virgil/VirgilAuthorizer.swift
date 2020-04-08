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
    public let verifier: VirgilCardVerifier
    public let client: Client

    public enum Error: Swift.Error {
        case cardVerifierInitFailed
    }

    public init() throws {
        self.crypto = try VirgilCrypto()
        self.client = Client(crypto: crypto)

        guard let verifier = VirgilCardVerifier(crypto: self.crypto) else {
            throw Error.cardVerifierInitFailed
        }

        self.verifier = verifier
    }

    public func signIn(identity: String) throws {
        let localKeyManager = try LocalKeyManager(identity: identity, crypto: self.crypto)

        guard try localKeyManager.exists() else {
            throw UserFriendlyError.noUserOnDevice
        }

        try Virgil.initialize(identity: identity, client: self.client)
    }

    public func signUp(identity: String, backendHost: String) throws {
        let localKeyManager = try LocalKeyManager(identity: identity, crypto: self.crypto)

        guard try !localKeyManager.exists() else {
            throw UserFriendlyError.usernameAlreadyUsed
        }

        let keyPair = try self.crypto.generateKeyPair()

        let card = try self.client.signUp(identity: identity,
                                          keyPair: keyPair,
                                          verifier: self.verifier,
                                          backendHost: backendHost)

        let user = UserData(keyPair: keyPair, card: card)
        try localKeyManager.store(user)

        try Virgil.initialize(identity: identity, client: self.client)
    }

    public func logOut() {
        try? Virgil.ethree.cleanUp()
    }
}
