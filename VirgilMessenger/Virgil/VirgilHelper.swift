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
    private let crypto: VSSCrypto
    private let keyStorage: VSSKeyStorage
    private let queue: DispatchQueue
    private let connection: ServiceConnection
    private let validator: VSSCardValidator
    private(set) var secureChat: SecureChat?
    private var publicKey: VSSPublicKey?
    private var privateKey: VSSPrivateKey?
    var channelCard: VSSCard?
    
    private let virgilAccessToken = "AT.cc7d17184199dc67b29edf6d57aa0a4db5a704590353d34cae0766f781eac03c"
    
    private let authId        = "1deb193fba41419083b655649e7f9bf8286c561feb5e34507d0bf99fed795eff"
    private let authPublicKey = "MCowBQYDK2VwAyEAk6RKNpA/dTCyZcMmwPErkRG0cYBVM4mcNZvRYE7+VL0="
    
    private let appCardId    = "4051f428fc7796fa8e736518ed7102ad21aac04aeec833feeeaf7e48b542900f"
    private let appPublicKey = "MCowBQYDK2VwAyEAf0HhVxDvT0wfgj986JkWYfTERCep5X0k4Ve28k+MO1w="

    private let twilioServer = "https://twilio.virgilsecurity.com/"
    private let authServer   = "https://auth-twilio.virgilsecurity.com/"
    
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
    
    enum VirgilHelperError: String, Error {
        case noKey                    =  "User not found on this device"
        case gettingVirgilTokenFailed =  "Getting Virgil Token Failed"
        case gettingTwilioTokenFailed =  "Getting Twilio Token Failed"
        case getCardFailed            =  "Getting Virgil Card Failed"
        case usernameAlreadyUsed      =  "Username is already in use"
        case buildCardFailed
        case importingKeyFailed
        case jsonFailed
        case dataFromString
        case validatingError
        case coreDataEncDecFailed
        case coreDataAccountFailed
    }
    
    private func initializePFS(withIdentity: String, card: VSSCard, privateKey: VSSPrivateKey) {
        do {
            let secureChatPreferences = try SecureChatPreferences (
                crypto: self.crypto,
                identityPrivateKey: privateKey,
                identityCard: card,
                accessToken: virgilAccessToken)
            
            let secureChat = SecureChat(preferences: secureChatPreferences)
                
            try secureChat.initialize()
            
            secureChat.rotateKeys(desiredNumberOfCards: 100) { error in
                guard error == nil else {
                    Log.error("Rotating keys: \(error!.localizedDescription). Error code: \((error! as NSError).code)")
                    return
                }
                Log.debug("Successfully initialized PFS")
            }
            
            self.secureChat = secureChat
        } catch {
            Log.error("Error while initializing PFS")
        }
    }
    
    func deleteStorageEntry(entry: String) {
        do {
            try self.keyStorage.deleteKeyEntry(withName: entry)
        } catch {
            Log.error("can't delete from key storage")
        }
    }
    
    func setChannelCard(_ exportedCard: String) {
        self.channelCard = VSSCard(data: exportedCard)
    }
    
    func getCard(withIdentity: String, completion: @escaping (VSSCard?, Error?) -> ()) {
        let serviceConfig = VSSServiceConfig(token: self.virgilAccessToken)
    
        serviceConfig.cardValidator = self.validator
        
        let client = VSSClient(serviceConfig: serviceConfig)
        
        let criteria = VSSSearchCardsCriteria(identity: withIdentity)
        
        client.searchCards(using: criteria) { (cards, error) in
            guard error == nil, let cards = cards else {
                Log.error("getting Virgil Card failed")
                completion(nil, VirgilHelperError.getCardFailed)
                return
            }
            
            completion(cards[0], nil)
        }
    }
    
    private func signInHelper(card: VSSCard, identity: String, completion: @escaping (Error?) -> ()) {
        self.publicKey = self.crypto.importPublicKey(from: card.publicKeyData)
        self.initializeAccount(withCardId: card.identifier, identity: identity) { error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
        do {
            let entry = try self.keyStorage.loadKeyEntry(withName: identity)
            guard let key = self.crypto.importPrivateKey(from: entry.value) else {
                throw VirgilHelperError.importingKeyFailed
            }
            self.privateKey = key
            
            self.initializePFS(withIdentity: identity, card: card, privateKey: key)
        } catch {
            Log.error("Signing in: key not found")
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }
    
    func signIn(identity: String, completion: @escaping (Error?, String?) -> ()) {
        Log.debug("Signing in")
        
        if (!keyStorage.existsKeyEntry(withName: identity)) {
            DispatchQueue.main.async {
                completion(VirgilHelperError.noKey, VirgilHelperError.noKey.rawValue)
            }
            Log.debug("Key not found")
            return
        }
        
        guard CoreDataHelper.sharedInstance.loadAccount(withIdentity: identity) else {
            DispatchQueue.main.async {
                completion(VirgilHelperError.coreDataAccountFailed, VirgilHelperError.noKey.rawValue)
            }
            return
        }
        
        let exportedCard = CoreDataHelper.sharedInstance.getAccountCard()
        
        if let exportedCard = exportedCard, let card = VSSCard(data: exportedCard) {
            self.signInHelper(card: card, identity: identity) { error in
                DispatchQueue.main.async {
                    completion(error, nil)
                }
            }
        } else {
            getCard(withIdentity: identity) { card, error in
                guard error == nil, let card = card else {
                    Log.error("Signing in: can't get virgil card")
                    DispatchQueue.main.async {
                        completion(error, nil)
                    }
                    return
                }
                
                self.signInHelper(card: card, identity: identity) { error in
                    DispatchQueue.main.async {
                        completion(error, nil)
                    }
                }
            }
        }
    }
    
    func decrypt(encrypted: String) throws -> String {
        guard let privateKey = self.privateKey,
              let data = Data(base64Encoded: encrypted)
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
    
    func encrypt(text: String) throws -> String {
        guard let publicKey = self.publicKey,
              let data = text.data(using: .utf8)
        else {
            Log.error("encrypting for Core Data failed")
            throw VirgilHelperError.coreDataEncDecFailed
        }
        
        let encrypted = try self.crypto.encrypt(data, for: [publicKey])
        return encrypted.base64EncodedString()
    }
    
    func signUp(identity: String, identityType: String = "name", completion: @escaping (Error?, String?) -> ()) {
        self.queue.async {
            Log.debug("Signing up")
        
            if (self.keyStorage.existsKeyEntry(withName: identity)) {
                Log.debug("Key already stored for this identity")
                DispatchQueue.main.async {
                    completion(VirgilHelperError.usernameAlreadyUsed, VirgilHelperError.usernameAlreadyUsed.rawValue)
                }
                return
            }
            do {
                let keyPair = self.crypto.generateKeyPair()
                self.publicKey = keyPair.publicKey
                self.privateKey = keyPair.privateKey
                let exportedPublicKey = self.crypto.export(keyPair.publicKey)
                
                let csr = VSSCreateUserCardRequest(identity: identity, identityType: identityType, publicKeyData: exportedPublicKey, data: ["deviceId": "testDevice123"])
                
                let signer = VSSRequestSigner(crypto: self.crypto)
                try signer.selfSign(csr, with: keyPair.privateKey)
                
                let exportedCSR = csr.exportData()
                
                let request = try ServiceRequest(url: URL(string: self.twilioServer + "v1/users")!, method: ServiceRequest.Method.post, headers: ["Content-Type":"application/json"], params: ["csr" : exportedCSR])
                
                let response = try self.connection.send(request)
                
                guard let responseBody = response.body,
                      let json = try JSONSerialization.jsonObject(with: responseBody, options: []) as? [String: Any]
                else {
                    Log.error("json failed")
                    throw VirgilHelperError.jsonFailed
                }
                
                 guard let exportedCard = json["virgil_card"] as? String else {
                     Log.error("Error while signing up: server didn't return card")
                     DispatchQueue.main.async {
                        completion(VirgilHelperError.usernameAlreadyUsed, VirgilHelperError.usernameAlreadyUsed.rawValue)
                     }
                     return
                 }
                guard let card = VSSCard(data: exportedCard) else {
                    Log.error("Can't build card")
                    throw VirgilHelperError.buildCardFailed
                }
                
                guard self.validator.validate(card.cardResponse) else {
                    Log.error("validating card failed")
                    throw VirgilHelperError.validatingError
                }
                
                
                let keyEntry = VSSKeyEntry(name: identity, value: self.crypto.export(keyPair.privateKey, withPassword: nil))
                
                try? self.keyStorage.deleteKeyEntry(withName: identity)
                try self.keyStorage.store(keyEntry)
                
                CoreDataHelper.sharedInstance.createAccount(withIdentity: identity, exportedCard: card.exportData())
                self.initializeAccount(withCardId: card.identifier, identity: identity) { error in
                    DispatchQueue.main.async {
                        completion(error, nil)
                    }
                }
                self.initializePFS(withIdentity: identity, card: card, privateKey: keyPair.privateKey)
            } catch {
                Log.error("Error while signing up")
                DispatchQueue.main.async {
                    completion(error, nil)
                }
            }
        }
    }
    
    private func initializeAccount(withCardId cardId: String, identity: String, completion: @escaping (Error?) -> ()) {
        self.queue.async {
            do {
                let VirgilToken = try self.getVirgilToken(withCardId: cardId, identity: identity)
                
                self.getTwilioToken(VirgilToken: VirgilToken) { token, error in
                    guard let token = token, error == nil else {
                        completion(error ?? VirgilHelperError.gettingTwilioTokenFailed)
                        return
                    }
                    TwilioHelper.authorize(username: identity, device: "iPhone")
                    TwilioHelper.sharedInstance.initialize(token: token) { error in
                        guard error == nil else {
                            completion(error)
                            return
                        }
                        completion(nil)
                    }
                }
            } catch {
                completion(VirgilHelperError.gettingVirgilTokenFailed)
                return
            }
        }
    }
    
    private func getTwilioToken(VirgilToken: String, completion: @escaping (String?, Error?) -> ()) {
        self.queue.async {
            do {
                let VirgilToken = "bearer " + VirgilToken
                let requestForTwilioToken = try ServiceRequest(url: URL(string: self.twilioServer + "v1/tokens/twilio")!, method: ServiceRequest.Method.get, headers: ["Authorization": VirgilToken])
                let responseWithTwilioToken = try self.connection.send(requestForTwilioToken)
                
                guard let responseWithTwilioTokenBody = responseWithTwilioToken.body,
                      let twilioTokenJson = try JSONSerialization.jsonObject(with: responseWithTwilioTokenBody, options: []) as? [String: Any],
                      let twilioToken = twilioTokenJson["twilioToken"] as? String
                else {
                    throw VirgilHelperError.gettingTwilioTokenFailed
                }
                
                completion(twilioToken, nil)
            } catch {
                Log.error("Error while getting twilio token")
                completion(nil, error)
            }
        }
    }
    
    private func getVirgilToken(withCardId: String, identity: String) throws -> String {
        let requestForGrantId = try ServiceRequest(url: URL(string: self.authServer + "v4/authorization-grant/actions/get-challenge-message")!, method: ServiceRequest.Method.post, headers: ["Content-Type":"application/json"], params: ["resource_owner_virgil_card_id" : withCardId])
        
        let responseWithGrantId =  try self.connection.send(requestForGrantId)

        let entry = try self.keyStorage.loadKeyEntry(withName: identity)
        
        guard let responseWithGrantIdBody = responseWithGrantId.body,
              let jsonWithGrantId = try JSONSerialization.jsonObject(with: responseWithGrantIdBody, options: []) as? [String: Any],
              let encryptedMessage = jsonWithGrantId["encrypted_message"] as? String,
              let authGrantId = jsonWithGrantId["authorization_grant_id"] as? String,
              let data = Data(base64Encoded: encryptedMessage),
              let privateKey = self.crypto.importPrivateKey(from: entry.value),
              let authPublicKeyData = Data(base64Encoded: self.authPublicKey),
              let importedPublicKey = self.crypto.importPublicKey(from: authPublicKeyData)
        else {
            throw VirgilHelperError.gettingVirgilTokenFailed
        }
        
        let decodedMessage = try self.crypto.decrypt(data, with: privateKey)
        
        let newEncryptedMessage = try self.crypto.encrypt(decodedMessage, for: [importedPublicKey])
        let message = newEncryptedMessage.base64EncodedString()
        
        let requestForCode = try ServiceRequest(url: URL(string: self.authServer + "v4/authorization-grant/" + authGrantId + "/actions/acknowledge")!, method: ServiceRequest.Method.post, headers: ["Content-Type":"application/json"], params: ["encrypted_message": message])
        
        let responseWithCode = try self.connection.send(requestForCode)
        
        guard let responseWithCodeBody = responseWithCode.body,
              let jsonWithCode = try JSONSerialization.jsonObject(with: responseWithCodeBody, options: []) as? [String: Any],
              let code = jsonWithCode["code"] as? String
        else {
            throw VirgilHelperError.gettingVirgilTokenFailed
        }
        
        let requestForVirgilToken = try ServiceRequest(url: URL(string: self.authServer + "v4/authorization/actions/obtain-access-token")!, method: ServiceRequest.Method.post, headers: ["Content-Type":"application/json"], params: ["grant_type": "access_code", "code": code])
        
        let responseWithVirgilToken = try self.connection.send(requestForVirgilToken)
        
        guard let responseWithVirgilTokenBody = responseWithVirgilToken.body,
            let jsonWithVirgilToken = try JSONSerialization.jsonObject(with: responseWithVirgilTokenBody, options: []) as? [String: Any],
            let accessToken = jsonWithVirgilToken["access_token"] as? String
            else {
                throw VirgilHelperError.gettingVirgilTokenFailed
        }
        
        return accessToken
    }
}
