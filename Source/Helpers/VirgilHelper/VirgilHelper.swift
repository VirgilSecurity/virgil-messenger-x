//
//  VirgilHelper.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 11/4/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import VirgilSDK
import VirgilCrypto
import VirgilSDKRatchet
import VirgilCryptoRatchet

class VirgilHelper {
    static let sharedInstance = VirgilHelper()

    let crypto: VirgilCrypto
    let cardCrypto: VirgilCardCrypto
    let keyStorage: KeyStorage
    let verifier: VirgilCardVerifier

    let client = Client()
    let queue = DispatchQueue(label: "virgil-help-queue")

    private(set) var privateKey: VirgilPrivateKey?
    private(set) var selfCard: Card?
    private(set) var secureChat: SecureChat?
    private var channelCard: Card?

    private init() {
        // FIXME
        self.crypto = try! VirgilCrypto()
        self.keyStorage = KeyStorage()
        self.cardCrypto = VirgilCardCrypto(virgilCrypto: self.crypto)
        self.verifier = VirgilCardVerifier(cardCrypto: self.cardCrypto)!
    }

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
        case cardVerifierInitFailed
    }

    internal func makeInitPFSOperation(identity: String, cardId: String, privateKey: VirgilPrivateKey) -> GenericOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                guard let cardId = self.selfCard?.identifier, let privateKey = self.privateKey else {
                    throw NSError()
                }

                let provider = self.client.makeAccessTokenProvider(identity: identity,
                                                                   cardId: cardId,
                                                                   crypto: self.crypto,
                                                                   privateKey: privateKey)
                let context = SecureChatContext(identity: identity, identityCardId: cardId, identityPrivateKey: privateKey, accessTokenProvider: provider)
                let secureChat = try SecureChat(context: context)

                let rotationLog = try secureChat.rotateKeys().startSync().getResult()
                Log.debug(rotationLog.description)

                self.secureChat = secureChat

                completion((), nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    private func getSessionAsSender() throws -> SecureSession {
        guard let card = self.channelCard else {
            Log.error("channel card not found")
            throw NSError()
        }

        guard let secureChat = self.secureChat else {
            Log.error("nil Secure Chat")
            throw NSError()
        }
        
        guard let session = secureChat.existingSession(withParticpantIdentity: card.identity) else {
            return try secureChat.startNewSessionAsSender(receiverCard: card).startSync().getResult()
        }

        return session
    }

    private func getSessionAsReceiver(message: RatchetMessage) throws -> SecureSession {
        guard let card = self.channelCard else {
            Log.error("channel card not found")
            throw NSError()
        }

        guard let secureChat = self.secureChat else {
            Log.error("nil Secure Chat")
            throw NSError()
        }

        guard let session = secureChat.existingSession(withParticpantIdentity: card.identity) else {
            return try secureChat.startNewSessionAsReceiver(senderCard: card, ratchetMessage: message)
        }

        return session
    }

    func encryptPFS(_ text: String) throws -> String {
        let session = try self.getSessionAsSender()

        let ratchetMessage = try session.encrypt(string: text)

        return ratchetMessage.serialize().base64EncodedString()
    }

    func decryptPFS(_ encrypted: String) throws -> String {
        guard let data = Data(base64Encoded: encrypted) else {
            Log.error("Converting utf8 string to data failed")
            throw NSError()
        }

        let ratchetMessage = try RatchetMessage.deserialize(input: data)

        let session = try self.getSessionAsReceiver(message: ratchetMessage)

        return try session.decryptString(from: ratchetMessage)
    }

    func encrypt(_ text: String) -> String? {
        let session = try! self.getSessionAsSender()

        let ratchetMessage = try! session.encrypt(string: text)

        return ratchetMessage.serialize().base64EncodedString()
    }

    func decrypt(_ encrypted: String) -> String? {
        guard let data = Data(base64Encoded: encrypted) else {
            Log.error("Converting utf8 string to data failed")
            return nil
        }

        let ratchetMessage = try! RatchetMessage.deserialize(input: data)

        let session = try! self.getSessionAsReceiver(message: ratchetMessage)

        return try! session.decryptString(from: ratchetMessage)
    }

    func getExportedCard(identity: String, completion: @escaping (String?, Error?) -> ()) {
//        self.getCard(identity: identity) { card, error in
//            guard let card = card, error == nil else {
//                DispatchQueue.main.async {
//                    completion(nil, error)
//                }
//                return
//            }
//            do {
//                let exportedCard = try card.getRawCard().exportAsBase64EncodedString()
//                DispatchQueue.main.async {
//                    completion(exportedCard, nil)
//                }
//            } catch {
//                DispatchQueue.main.async {
//                    completion(nil, error)
//                }
//            }
//        }
    }

    /// Returns Virgil Card with given identity
    ///
    /// - Parameters:
    ///   - identity: identity to search
    ///   - completion: completion handler, called with card if succeded and error otherwise
//    private func getCard(identity: String, completion: @escaping (Card?, Error?) -> ()) {
//        guard let cardManager = self.cardManager else {
//            Log.error("Missing CardManager")
//            completion(nil, VirgilHelperError.missingCardManager)
//            return
//        }
//
//        cardManager.searchCards(identity: identity) { cards, error in
//            guard error == nil, let card = cards?.first else {
//                Log.error("Getting Virgil Card failed")
//                completion(nil, VirgilHelperError.getCardFailed)
//                return
//            }
//            completion(card, nil)
//        }
//    }

    func deleteStorageEntry(entry: String) {
        do {
            try self.keyStorage.deleteKeyEntry(withName: entry)
        } catch {
            Log.error("Can't delete from key storage: \(error.localizedDescription)")
        }
    }

    func buildCard(_ card: String) -> Card? {
        do {
            let card = try self.importCard(fromBase64Encoded: card)
            return card
        } catch {
            Log.error("Importing Card failed with: \(error.localizedDescription)")

            return nil
        }
    }

    func setChannelCard(_ card: String) {
        do {
            let importedCard = try self.importCard(fromBase64Encoded: card)

            self.channelCard = importedCard
        } catch {
            Log.error("Importing Card failed with: \(error.localizedDescription)")
        }
    }

    func importCard(fromBase64Encoded card: String) throws -> Card {
        return try CardManager.importCard(fromBase64Encoded: card,
                                          cardCrypto: self.cardCrypto,
                                          cardVerifier: self.verifier)
    }

    func importCard(fromJson card: Any) throws -> Card {
        return try CardManager.importCard(fromJson: card,
                                          cardCrypto: self.cardCrypto,
                                          cardVerifier: self.verifier)
    }

    func export(card: Card) throws -> String {
        return try CardManager.exportCardAsBase64EncodedString(card)
    }

    /// Exports self Card
    ///
    /// - Returns: exported self Card
    func getExportedSelfCard() -> String? {
        guard let card = self.selfCard else {
            return nil
        }

        return try? self.export(card: card)
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
}
