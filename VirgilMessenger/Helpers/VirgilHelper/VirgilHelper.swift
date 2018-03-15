//
//  VirgilHelper.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 11/4/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import VirgilSDKPFS

class VirgilHelper {
    static let sharedInstance = VirgilHelper()
    let crypto: VSSCrypto
    let keyStorage: VSSKeyStorage
    let queue: DispatchQueue
    let connection: ServiceConnection
    let validator: VSSCardValidator

    private var secureChat: SecureChat?
    private var publicKey: VSSPublicKey?
    private var privateKey: VSSPrivateKey?
    private var channelCard: VSSCard?

    let virgilAccessToken = "AT.cc7d17184199dc67b29edf6d57aa0a4db5a704590353d34cae0766f781eac03c"
    let authId = "1deb193fba41419083b655649e7f9bf8286c561feb5e34507d0bf99fed795eff"
    let authPublicKey = "MCowBQYDK2VwAyEAk6RKNpA/dTCyZcMmwPErkRG0cYBVM4mcNZvRYE7+VL0="
    let appCardId = "4051f428fc7796fa8e736518ed7102ad21aac04aeec833feeeaf7e48b542900f"
    let appPublicKey = "MCowBQYDK2VwAyEAf0HhVxDvT0wfgj986JkWYfTERCep5X0k4Ve28k+MO1w="
    let twilioServer = "https://twilio.virgilsecurity.com/"
    let authServer = "https://auth-twilio.virgilsecurity.com/"

    private init() {
        self.crypto = VSSCrypto()
        self.keyStorage = VSSKeyStorage()
        self.queue = DispatchQueue(label: "virgil-help-queue")
        self.connection = ServiceConnection()

        self.validator = VSSCardValidator(crypto: crypto)

        guard let appPublicKeyData = Data(base64Encoded: self.appPublicKey) else {
            Log.error("error converting appPublicKey to data")
            return
        }
        self.validator.addVerifier(withId: appCardId, publicKeyData: appPublicKeyData)
    }

    enum UserFriendlyError: String, Error {
        case noUserOnDevice = "User not found on this device"
        case usernameAlreadyUsed = "Username is already in use"
    }

    enum VirgilHelperError: String, Error {
        case gettingVirgilTokenFailed = "Getting Virgil Token Failed"
        case gettingTwilioTokenFailed = "Getting Twilio Token Failed"
        case getCardFailed = "Getting Virgil Card Failed"
        case buildCardFailed
        case importingKeyFailed
        case jsonParsingFailed
        case dataFromString
        case validatingError
        case coreDataEncDecFailed
        case coreDataAccountFailed
    }

    func initializePFS(withIdentity: String, card: VSSCard, privateKey: VSSPrivateKey, completion: @escaping (Error?) -> ()) {
        do {
            let secureChatPreferences = try SecureChatPreferences(crypto: self.crypto,
                                                                  identityPrivateKey: privateKey,
                                                                  identityCard: card,
                                                                  accessToken: virgilAccessToken)
            let secureChat = SecureChat(preferences: secureChatPreferences)
            try secureChat.initialize()

            secureChat.rotateKeys(desiredNumberOfCards: 100) { error in
                if error != nil {
                    Log.error("Rotating keys: \(error!.localizedDescription). Error code: \((error! as NSError).code)")
                } else {
                    Log.debug("Successfully initialized PFS")
                }
                self.secureChat = secureChat
                completion(error)
            }
        } catch {
            Log.error("Error while initializing PFS: \(error.localizedDescription)")
        }
    }

    func getCard(withIdentity: String, completion: @escaping (VSSCard?, Error?) -> ()) {
        let serviceConfig = VSSServiceConfig(token: self.virgilAccessToken)
        serviceConfig.cardValidator = self.validator
        let client = VSSClient(serviceConfig: serviceConfig)

        let criteria = VSSSearchCardsCriteria(identity: withIdentity)
        client.searchCards(using: criteria) { cards, error in
            guard error == nil, let cards = cards else {
                Log.error("getting Virgil Card failed")
                completion(nil, VirgilHelperError.getCardFailed)
                return
            }
            completion(cards[0], nil)
        }
    }

    func encryptPFS(message: String, completion: @escaping (String?) -> ()) {
        self.getSession { session in
            guard let session = session else {
                completion(nil)
                return
            }
            do {
                let encrypted = try session.encrypt(message)
                completion(encrypted)
            } catch {
                Log.error("enrypting PFS failed: \(error.localizedDescription)")
                completion(nil)
                return
            }
        }
    }

    func decryptPFS(cardString: String? = nil, encrypted: String) -> String? {
        var card: VSSCard
        if let cardString = cardString {
            guard let builtCard = self.buildCard(cardString) else {
                Log.error("building card from string failed")
                return nil
            }
            card = builtCard
        } else {
            guard let channelCard = self.channelCard  else {
                Log.error("channel card not found")
                return nil
            }
            card = channelCard
        }
        guard let secureChat = self.secureChat else {
            Log.error("nil secure Chat")
            return nil
        }
        do {
            let session = try secureChat.loadUpSession(withParticipantWithCard: card,
                                                       message: encrypted)
            return try session.decrypt(encrypted)
        } catch {
            Log.error("decrypting PFS: \(error.localizedDescription)")
        }
        return nil
    }

    private func getSession(completion: @escaping (SecureSession?) -> ()) {
        guard let card = self.channelCard else {
            Log.error("channel card not found")
            completion(nil)
            return
        }
        Log.debug("encrypting for " + card.identity)
        guard let secureChat = self.secureChat else {
            Log.error("nil Secure Chat")
            completion(nil)
            return
        }
        guard let session = secureChat.activeSession(withParticipantWithCardId: card.identifier) else {
            secureChat.startNewSession(withRecipientWithCard: card) { session, error in
                guard error == nil, let session = session else {
                    let errorMessage = error == nil ? "unknown error" : error!.localizedDescription
                    Log.error("creating session failed: " + errorMessage)
                    completion(nil)
                    return
                }
                completion(session)
            }
            return
        }
        completion(session)
    }

    func encrypt(text: String) throws -> String {
        guard let data = text.data(using: .utf8)
            else {
                Log.error("encrypting for Core Data failed")
                throw VirgilHelperError.coreDataEncDecFailed
        }
        let encrypted = try self.encrypt(data: data)

        return encrypted.base64EncodedString()
    }

    func encrypt(data: Data) throws -> Data {
        guard let publicKey = self.publicKey else {
                Log.error("encrypting for Core Data failed")
                throw VirgilHelperError.coreDataEncDecFailed
        }
        let encrypted = try self.crypto.encrypt(data, for: [publicKey])

        return encrypted
    }

    func decrypt(text: String) throws -> String {
        guard let privateKey = self.privateKey,
            let data = Data(base64Encoded: text)
            else {
                Log.error("decrypting for Core Data failed")
                throw VirgilHelperError.coreDataEncDecFailed
        }
        let decryptedData = try self.crypto.decrypt(data, with: privateKey)

        guard let decrypted = String(data: decryptedData, encoding: .utf8) else {
            Log.error("building string from data failed")
            throw VirgilHelperError.coreDataEncDecFailed
        }

        return decrypted
    }

    func decrypt(data: Data) throws -> Data {
        guard let privateKey = self.privateKey else {
                Log.error("Private Key not found")
                throw VirgilHelperError.coreDataEncDecFailed
        }
        let decryptedData = try self.crypto.decrypt(data, with: privateKey)

        return decryptedData
    }

    func deleteStorageEntry(entry: String) {
        do {
            try self.keyStorage.deleteKeyEntry(withName: entry)
        } catch {
            Log.error("can't delete from key storage: \(error.localizedDescription)")
        }
    }

    func buildCard(_ exportedCard: String) -> VSSCard? {
        return VSSCard(data: exportedCard)
    }
}

/// Setters
extension VirgilHelper {
    func setPrivateKey(_ key: VSSPrivateKey) {
        self.privateKey = key
    }

    func setPublicKey(_ key: VSSPublicKey) {
        self.publicKey = key
    }

    func setChannelCard(_ card: VSSCard?) {
        self.channelCard = card
    }

    func setChannelCard(_ exportedCard: String) {
        self.channelCard = VSSCard(data: exportedCard)
    }
}
