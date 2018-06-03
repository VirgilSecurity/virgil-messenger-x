//
//  VirgilHelper.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 11/4/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import VirgilSDK
import VirgilCryptoApiImpl

class VirgilHelper {
    static let sharedInstance = VirgilHelper()
    let crypto: VirgilCrypto
    let cardCrypto: VirgilCardCrypto
    let keyStorage: KeyStorage
    let queue: DispatchQueue
    let connection: ServiceConnection
    let verifier: VirgilCardVerifier

    private(set) var privateKey: VirgilPrivateKey?
    private(set) var selfCard: Card?
    private(set) var cardManager: CardManager?
    private var channelKeys: [VirgilPublicKey] = []

    /// Enpoints to backend
    let virgilJwtEndpoint = "http://localhost:3000/get-virgil-jwt/"
    let twilioJwtEndpoint = "http://localhost:3000/get-twilio-jwt/"
    let signUpEndpint = "http://localhost:3000/signup/"
    let signInEndpint = "http://localhost:3000/signin/"

    private init() {
        self.crypto = VirgilCrypto()
        self.keyStorage = KeyStorage()
        self.queue = DispatchQueue(label: "virgil-help-queue")
        self.connection = ServiceConnection()
        self.cardCrypto = VirgilCardCrypto()
        self.verifier = VirgilCardVerifier(cardCrypto: self.cardCrypto)!
    }

    /// Errors to be displayed to user
    ///
    /// - noUserOnDevice: User not found on this device
    /// - usernameAlreadyUsed: Username is already in use
    enum UserFriendlyError: String, Error {
        case noUserOnDevice = "User not found on this device"
        case usernameAlreadyUsed = "Username is already in use"
    }

    enum VirgilHelperError: String, Error {
        case gettingTwilioTokenFailed = "Getting Twilio Token Failed"
        case getCardFailed = "Getting Virgil Card Failed"
        case keyIsNotVirgil = "Converting Public or Private Key to Virgil one failed"
        case missingCardManager = "Missing Card Manager"
        case gettingJwtFailed = "Getting JWT failed"
        case jsonParsingFailed
        case cardWasNotVerified
    }

    /// Encrypts given String
    ///
    /// - Parameter text: String to encrypt
    /// - Returns: encrypted String
    /// - Throws: error if fails
    func encrypt(_ text: String) -> String? {
        guard let data = text.data(using: .utf8) else {
            Log.error("Converting utf8 string to data failed")
            return nil
        }

        do {
            let encrypted = try self.crypto.encrypt(data, for: self.channelKeys).base64EncodedString()

            return encrypted
        } catch {
            Log.error("Encrypting failed with error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Decrypts given String
    ///
    /// - Parameter encrypted: String to decrypt
    /// - Returns: decrypted String
    /// - Throws: error if fails
    func decrypt(_ encrypted: String) -> String? {
        guard let privateKey = self.privateKey else {
            Log.error("Missing self private key")
            return nil
        }

        guard let data = Data(base64Encoded: encrypted) else {
            Log.error("Converting utf8 string to data failed")
            return nil
        }

        do {
            let decryptedData = try self.crypto.decrypt(data, with: privateKey)
            guard let decrypted = String(data: decryptedData, encoding: .utf8) else {
                Log.error("Building string from data failed")
                return nil
            }

            return decrypted
        } catch {
            Log.error("Decrypting failed with error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Returns exported Virgil Card with given identity
    ///
    /// - Parameters:
    ///   - identity: identity to search
    ///   - completion: completion handler, called with exported card if succeded and error otherwise
    func getExportedCard(identity: String, completion: @escaping (String?, Error?) -> ()) {
        self.getCard(identity: identity) { card, error in
            guard let card = card, error == nil else {
                completion(nil, error)
                return
            }
            do {
                let exportedCard = try card.getRawCard().exportAsBase64EncodedString()
                completion(exportedCard, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    /// Returns Virgil Card with given identity
    ///
    /// - Parameters:
    ///   - identity: identity to search
    ///   - completion: completion handler, called with card if succeded and error otherwise
    func getCard(identity: String, completion: @escaping (Card?, Error?) -> ()) {
        guard let cardManager = self.cardManager else {
            Log.error("Missing CardManager")
            DispatchQueue.main.async {
                completion(nil, VirgilHelperError.missingCardManager)
            }
            return
        }
        cardManager.searchCards(identity: identity) { cards, error in
            guard error == nil, let card = cards?.first else {
                Log.error("Getting Virgil Card failed")
                completion(nil, VirgilHelperError.getCardFailed)
                return
            }
            completion(card, nil)
        }
    }

    /// Deletes key storage entry
    ///
    /// - Parameter entry: key entry to delete
    func deleteStorageEntry(entry: String) {
        do {
            try self.keyStorage.deleteKeyEntry(withName: entry)
        } catch {
            Log.error("Can't delete from key storage: \(error.localizedDescription)")
        }
    }

    /// Imports Card from string
    ///
    /// - Parameter exportedCard: exported card as base64
    /// - Returns: Card if succeded, nil otherwise
    func buildCard(_ exportedCard: String) -> Card? {
        guard let cardManager = self.cardManager else {
            Log.error("Missing CardManager")
            return nil
        }
        do {
            return try cardManager.importCard(fromBase64Encoded: exportedCard)
        } catch {
            Log.error("Importing Card failed with: \(error.localizedDescription)")

            return nil
        }
    }

    /// Sets channels keys to encrypt for
    ///
    /// - Parameter exportedCards: exported cards array
    func setChannelKeys(_ exportedCards: [String]) {
        guard let cardManager = self.cardManager else {
            Log.error("Missing CardManager")
            return
        }
        self.channelKeys = []

        do {
            for exportedCard in exportedCards {
                let importedCard = try cardManager.importCard(fromBase64Encoded: exportedCard)
                guard let publicKey = importedCard.publicKey as? VirgilPublicKey else {
                    throw VirgilHelperError.keyIsNotVirgil
                }
                self.channelKeys.append(publicKey)
            }
        } catch {
            Log.error("Importing Card failed with: \(error.localizedDescription)")
        }
    }
}

/// Setters
extension VirgilHelper {
    func set(privateKey: VirgilPrivateKey) {
        self.privateKey = privateKey
    }

    func set(selfCard: Card) {
        self.selfCard = selfCard
    }

    func set(cardManager: CardManager) {
        self.cardManager = cardManager
    }
}
