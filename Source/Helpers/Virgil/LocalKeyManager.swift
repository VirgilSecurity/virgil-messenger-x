//
//  LocalKeyManager.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/18/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilCrypto
import VirgilSDK

public struct UserData {
    public let keyPair: VirgilKeyPair
    public let card: Card
}

public class LocalKeyManager {
    private let identity: String
    private let keychainStorage: KeychainStorage
    private let crypto: VirgilCrypto
    private let cardCrypto: VirgilCardCrypto

    public enum KeychainMetaKeys: String {
        case rawCard = "rawCard"
    }

    public init(identity: String, crypto: VirgilCrypto) throws {
        self.identity = identity
        self.crypto = crypto
        self.cardCrypto = VirgilCardCrypto(virgilCrypto: crypto)

        let storageParams = try KeychainStorageParams.makeKeychainStorageParams()
        self.keychainStorage = KeychainStorage(storageParams: storageParams)
    }

    public func retrieveUserData() -> UserData? {
        guard let keyEntry = try? self.keychainStorage.retrieveEntry(withName: self.identity),
            let keyPair = try? self.crypto.importPrivateKey(from: keyEntry.data),
            let meta = keyEntry.meta,
            let rawCardBase64 = meta[KeychainMetaKeys.rawCard.rawValue],
            let rawCard = try? RawSignedModel.import(fromBase64Encoded: rawCardBase64),
            let card = try? CardManager.parseCard(from: rawCard, cardCrypto: cardCrypto) else {
                return nil
        }

        return UserData(keyPair: keyPair, card: card)
    }

    public func store(_ user: UserData) throws {
        let data = try self.crypto.exportPrivateKey(user.keyPair.privateKey)
        let rawCard = try CardManager.exportCardAsBase64EncodedString(user.card)
        let meta = [KeychainMetaKeys.rawCard.rawValue: rawCard]

        _ = try self.keychainStorage.store(data: data, withName: self.identity, meta: meta)
    }

    public func exists() throws -> Bool {
        return try self.keychainStorage.existsEntry(withName: self.identity)
    }

    public func delete() throws {
        try self.keychainStorage.deleteEntry(withName: self.identity)
    }
}
