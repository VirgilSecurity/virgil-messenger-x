//
//  Virgil.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 11/4/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import VirgilCrypto
import VirgilCryptoFoundation
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
        params.appGroup = Constants.appGroup
        params.enableRatchet = true
        params.enableRatchetPqc = true
        params.keyPairType = Constants.keyPairType
        params.storageParams = try KeychainStorageParams.makeKeychainStorageParams(appName: Constants.KeychainGroup)

        self.ethree = try EThree(params: params)

        let verifier = VirgilCardVerifier(crypto: client.crypto)!

        self.shared = Virgil(client: client, verifier: verifier)
    }
    
    struct SymmetricEncryptResult {
        let encryptedData: Data
        let secret: Data
    }
    
    static func symmetricDecrypt(encryptedData: Data, secret: Data) throws -> Data {
        let aes = Aes256Gcm()
        
        aes.setKey(key: secret.prefix(aes.keyLen))
        aes.setNonce(nonce: secret.suffix(aes.nonceLen))
        
        return try aes.authDecrypt(data: encryptedData, authData: Data(), tag: Data())
    }
    
    static func symmetricEncrypt(data: Data) throws -> SymmetricEncryptResult {
        let aes = Aes256Gcm()
        
        let key = try Virgil.ethree.crypto.generateRandomData(ofSize: aes.keyLen)
        let nonce = try Virgil.ethree.crypto.generateRandomData(ofSize: aes.nonceLen)
        
        aes.setKey(key: key)
        aes.setNonce(nonce: nonce)
        
        let result = try aes.authEncrypt(data: data, authData: Data())
        
        return SymmetricEncryptResult(encryptedData: result.out + result.tag, secret: key + nonce)
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
