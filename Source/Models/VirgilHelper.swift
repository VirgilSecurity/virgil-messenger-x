//
//  VirgilHelper.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 11/4/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import VirgilCrypto
import VirgilSDKRatchet
import VirgilCryptoRatchet

class VirgilHelper {
    private(set) static var shared: VirgilHelper!

    let crypto: VirgilCrypto
    let cardCrypto: VirgilCardCrypto
    let verifier: VirgilCardVerifier
    let localKeyManager: LocalKeyManager

    let client: Client
    let queue = DispatchQueue(label: "VirgilHelperQueue")

    private(set) var secureChat: SecureChat
    private var channelCard: Card?

    private init(crypto: VirgilCrypto,
                 cardCrypto: VirgilCardCrypto,
                 verifier: VirgilCardVerifier,
                 client: Client,
                 localKeyManager: LocalKeyManager,
                 secureChat: SecureChat) {
        self.crypto = crypto
        self.cardCrypto = cardCrypto
        self.verifier = verifier
        self.client = client
        self.localKeyManager = localKeyManager
        self.secureChat = secureChat
    }

    public static func initialize(identity: String) throws {
        let crypto = try VirgilCrypto()
        let cardCrypto = VirgilCardCrypto(virgilCrypto: crypto)
        let client = Client(crypto: crypto, cardCrypto: cardCrypto)
        let localKeyManager = try LocalKeyManager(identity: identity, crypto: crypto)

        guard let verifier = VirgilCardVerifier(cardCrypto: cardCrypto) else {
            throw VirgilHelperError.cardVerifierInitFailed
        }

        guard let user = localKeyManager.retrieveUserData() else {
            throw NSError()
        }

        let provider = client.makeAccessTokenProvider(identity: identity,
                                                      cardId: user.card.identifier,
                                                      privateKey: user.privateKey)

        let context = SecureChatContext(identity: identity,
                                        identityCardId: user.card.identifier,
                                        identityPrivateKey: user.privateKey,
                                        accessTokenProvider: provider)

        let secureChat = try SecureChat(context: context)

        self.shared = VirgilHelper(crypto: crypto,
                                   cardCrypto: cardCrypto,
                                   verifier: verifier,
                                   client: client,
                                   localKeyManager: localKeyManager,
                                   secureChat: secureChat)
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

    public func makeInitPFSOperation(identity: String) -> GenericOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let rotationLog = try self.secureChat.rotateKeys().startSync().getResult()
                Log.debug(rotationLog.description)

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
        
        guard let session = secureChat.existingSession(withParticpantIdentity: card.identity) else {
            return try secureChat.startNewSessionAsSender(receiverCard: card).startSync().getResult()
        }

        return session
    }

    private func getSessionAsReceiver(message: RatchetMessage, receiverCard card: Card) throws -> SecureSession {
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

        guard let card = self.channelCard else {
            Log.error("channel card not found")
            throw NSError()
        }

        let ratchetMessage = try RatchetMessage.deserialize(input: data)

        let session = try self.getSessionAsReceiver(message: ratchetMessage, receiverCard: card)

        return try session.decryptString(from: ratchetMessage)
    }

    func encrypt(_ text: String) -> String? {
        let session = try! self.getSessionAsSender()

        let ratchetMessage = try! session.encrypt(string: text)

        return ratchetMessage.serialize().base64EncodedString()
    }

    func decrypt(_ encrypted: String, withCard: String? = nil) -> String? {
        guard let data = Data(base64Encoded: encrypted) else {
            Log.error("Converting utf8 string to data failed")
            return nil
        }

        let tryCard: Card?
        if let receiverCard = withCard {
            tryCard = self.buildCard(receiverCard)
        } else {
            tryCard = self.channelCard
        }

        guard let card = tryCard else {
            Log.error("No card")
            return nil
        }

        do {
            let ratchetMessage = try RatchetMessage.deserialize(input: data)

            let session = try self.getSessionAsReceiver(message: ratchetMessage, receiverCard: card)

            return try session.decryptString(from: ratchetMessage)
        } catch {
            Log.error("\(error.localizedDescription)")
            return nil
        }
    }

    func getExportedCard(identity: String, completion: @escaping (String?, Error?) -> ()) {
        guard let user = localKeyManager.retrieveUserData() else {
            completion(nil, NSError())
            return
        }

        self.client.searchCards(withIdentity: identity,
                                selfIdentity: user.card.identity,
                                cardId: user.card.identifier,
                                privateKey: user.privateKey,
                                verifier: self.verifier)
        { cards, error in
            do {
                guard let card = cards?.first, error == nil else {
                    throw VirgilHelperError.getCardFailed
                }

                let exportedCard = try card.getRawCard().exportAsBase64EncodedString()

                completion(exportedCard, nil)
            } catch {
                completion(nil, error)
            }
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

    func getTwilioToken(identity: String) throws -> String {
        return try self.client.getTwilioToken(identity: identity)
    }
}
