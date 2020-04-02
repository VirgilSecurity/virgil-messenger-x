//
//  Virgil.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 11/4/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import VirgilCrypto
import VirgilSDKRatchet
import VirgilCryptoRatchet

import VirgilE3Kit

public class Virgil {
    private(set) static var shared: Virgil!
    private(set) static var ethree: EThree!

    internal let verifier: VirgilCardVerifier
    internal let client: Client

    internal var crypto: VirgilCrypto {
        return self.client.crypto
    }

    private init(client: Client,
                 verifier: VirgilCardVerifier) {
        self.client = client
        self.verifier = verifier
    }

    public static func initialize(identity: String, client: Client) throws {
        let tokenCallback = client.makeTokenCallback(identity: identity)
        let params = EThreeParams(identity: identity, tokenCallback: tokenCallback)
        params.storageParams = try KeychainStorageParams.makeKeychainStorageParams(appName: Constants.KeychainGroup)
        params.enableRatchet = true
        params.securityApplicationGroupIdentifier = Constants.appGroup

        self.ethree = try EThree(params: params)

        let verifier = VirgilCardVerifier(crypto: client.crypto)!

        self.shared = Virgil(client: client, verifier: verifier)
    }

    func importCard(fromBase64Encoded card: String) throws -> Card {
        return try CardManager.importCard(fromBase64Encoded: card,
                                          crypto: self.crypto,
                                          cardVerifier: self.verifier)
    }

    func makeHash(from string: String) -> String {
        let data = string.data(using: .utf8)!

        return self.crypto.computeHash(for: data, using: .sha256).hexEncodedString()
    }
}
