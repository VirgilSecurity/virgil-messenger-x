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
    private(set) var secureChat: SecureChat?
    var channelCard: VSSCard?
    
    private let VirgilAccessToken = "AT.6968c649d331798cbbb757c2cfcae6475416ef958b41d3feddd103dee22a970b"
    private let AuthPublicKey = "MCowBQYDK2VwAyEAHQe7Uf+sUQASm3eGqaqMIfrbHKU9gKUnDg7AuVzf0Z0="
    
    private init() {
        self.crypto = VSSCrypto()
        self.keyStorage = VSSKeyStorage()
        self.queue = DispatchQueue(label: "virgil-help-queue")
        self.connection = ServiceConnection()
    }
    
    private func initializePFS(withIdentity: String, card: VSSCard, privateKey: VSSPrivateKey) {
        do {
            let secureChatPreferences = try! SecureChatPreferences (
                crypto: self.crypto,
                identityPrivateKey: privateKey,
                identityCard: card,
                accessToken: VirgilAccessToken)
            
            secureChatPreferences.pfsUrl = URL(string: "https://pfs.virgilsecurity.com/v1/")
            self.secureChat = SecureChat(preferences: secureChatPreferences)
                
            try self.secureChat?.initialize()
                
            self.secureChat?.rotateKeys(desiredNumberOfCards: 100) { error in
                guard error == nil else {
                    Log.error("Rotating keys: \(error!.localizedDescription)")
                    return
                }
                Log.debug("Successfully initialized PFS")
            }
        } catch {
            Log.error("Error while initializing PFS")
        }
    }
    
    func setChannelCard(_ exportedCard: String) {
        self.channelCard = VSSCard(data: exportedCard)
    }
    
    func getCard(withIdentity: String, completion: @escaping (VSSCard?, Error?) -> ()) {
        let serviceConfig = VSSServiceConfig(token: self.VirgilAccessToken)
        serviceConfig.cardsServiceURL = URL(string: "https://cards.virgilsecurity.com/v4/")!
        serviceConfig.cardsServiceROURL = URL(string: "https://cards-ro.virgilsecurity.com/v4/")!
        
        let client = VSSClient(serviceConfig: serviceConfig)
        
        let criteria = VSSSearchCardsCriteria(identity: withIdentity)
        
        client.searchCards(using: criteria) { (cards, error) in
            guard error == nil else {
                Log.error("Error: searching cards error")
                completion(nil, NSError())
                return
            }
            guard cards != nil else {
                Log.error("Error: no Virgil card found")
                completion(nil, NSError())
                return
            }
            
            completion(cards![0], nil)
        }
    }
    
    func signIn(identity: String, completion: @escaping (Error?) -> ()) {
        Log.debug("Signing in")
        
        if (!keyStorage.existsKeyEntry(withName: identity)) {
            completion(NSError())
            Log.debug("Key not found")
            return
        }
        
        CoreDataHelper.sharedInstance.loadAccount(withIdentity: identity)
        let exportedCard = CoreDataHelper.sharedInstance.getAccountCard()
        let card = VSSCard(data: exportedCard)!
        
            self.initializeAccount(withCardId: card.identifier, identity: identity) { error in
                DispatchQueue.main.async {
                    completion(error)
                }
            }
            do {
                let entry = try self.keyStorage.loadKeyEntry(withName: identity)
                let key = self.crypto.importPrivateKey(from: entry.value)
                self.initializePFS(withIdentity: identity, card: card, privateKey: key!)
            } catch {
                Log.error("Signing in: key not found")
                DispatchQueue.main.async {
                    completion(error)
                }
            }
    }
    
    func signUp(identity: String, identityType: String = "name", completion: @escaping (Error?) -> ()) {
        self.queue.async {
            Log.debug("Signing up")
            
            if (self.keyStorage.existsKeyEntry(withName: identity)) {
                Log.debug("Key already stored for this identity")
                DispatchQueue.main.async {
                    completion(NSError())
                }
                return
            }
            do {
                let keyPair = self.crypto.generateKeyPair()
                let exportedPublicKey = self.crypto.export(keyPair.publicKey)
                
                let csr = VSSCreateUserCardRequest(identity: identity, identityType: identityType, publicKeyData: exportedPublicKey, data: ["deviceId": "testDevice123"])
                
                let signer = VSSRequestSigner(crypto: self.crypto)
                try signer.selfSign(csr, with: keyPair.privateKey)
                
                let exportedCSR = csr.exportData()
                
                let request = try ServiceRequest(url: URL(string: "https://twilio.virgilsecurity.com/v1/users")!, method: ServiceRequest.Method.post, headers: ["Content-Type":"application/json"], params: ["csr" : exportedCSR])
                
                let response = try self.connection.send(request)
                
                let json = try JSONSerialization.jsonObject(with: response.body!, options: []) as? [String: Any]
                
                guard let cardId = json?["id"] as? String else {
                    Log.error("Error while signing up: server didn't return card")
                    throw NSError()
                }
                
                /*
                 var exportedCard = String(data: response.body!, encoding: .utf8)
                 exportedCard = exportedCard! + "}}}"
                 
                 Log.debug("card: " + exportedCard! + " - end")
                 let str = "asdasd"
                 let tr_card = VSSCard(data: str)
                 Log.debug("card id : " + tr_card!.identifier)*/
                
                let keyEntry = VSSKeyEntry(name: identity, value: self.crypto.export(keyPair.privateKey, withPassword: nil))
                if self.keyStorage.existsKeyEntry(withName: identity) {
                    try self.keyStorage.deleteKeyEntry(withName: identity)
                }
                try self.keyStorage.store(keyEntry)
                
                self.getCard(withIdentity: identity) { card, error in
                    guard let card = card, error == nil else {
                        DispatchQueue.main.async {
                            completion(error)
                        }
                        return
                    }
                    CoreDataHelper.sharedInstance.createAccount(withIdentity: identity, exportedCard: card.exportData())
                    self.initializeAccount(withCardId: cardId, identity: identity) { error in
                        DispatchQueue.main.async {
                            completion(error)
                        }
                    }
                    self.initializePFS(withIdentity: identity, card: card, privateKey: keyPair.privateKey)
                }
            } catch {
                Log.error("Error while signing up")
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }
    
    private func initializeAccount(withCardId cardId: String, identity: String, completion: @escaping (Error?) -> ()) {
        self.queue.async {
            let VirgilToken = self.getVirgilToken(withCardId: cardId, identity: identity)
            guard VirgilToken != "" else {
                completion(NSError())
                return
            }
            self.getTwilioToken(VirgilToken: VirgilToken) { token, error in
                guard error == nil else {
                    completion(error)
                    return
                }
                TwilioHelper.authorize(username: identity, device: "iPhone")
                TwilioHelper.sharedInstance.initialize(token: token!) { error in
                    guard error == nil else {
                        completion(error)
                        return
                    }
                    completion(nil)
                }
            }
        }
    }
    
    private func getTwilioToken(VirgilToken: String, completion: @escaping (String?, Error?) -> ()) {
        self.queue.async {
            do {
                let VirgilToken = "bearer " + VirgilToken
                let requestForTwilioToken = try ServiceRequest(url: URL(string: "https://twilio.virgilsecurity.com/v1/tokens/twilio")!, method: ServiceRequest.Method.get, headers: ["Authorization": VirgilToken])
                let responseWithTwilioToken = try self.connection.send(requestForTwilioToken)
                
                let twilioTokenJson = try! JSONSerialization.jsonObject(with: responseWithTwilioToken.body!, options: []) as? [String: Any]
                
                let twilioToken = twilioTokenJson?["twilioToken"] as? String
                
                completion(twilioToken, nil)
                
            } catch {
                Log.error("Error while getting twilio token")
                completion(nil, error)
            }
        }
    }
    
    private func getVirgilToken(withCardId: String, identity: String) -> String {
            do {
                let requestForGrantId = try ServiceRequest(url: URL(string: "https://auth-twilio.virgilsecurity.com/v4/authorization-grant/actions/get-challenge-message")!, method: ServiceRequest.Method.post, headers: ["Content-Type":"application/json"], params: ["resource_owner_virgil_card_id" : withCardId])
                
                let responseWithGrantId =  try self.connection.send(requestForGrantId)
                
                let jsonWithGrantId = try JSONSerialization.jsonObject(with: responseWithGrantId.body!, options: []) as? [String: Any]
                let encryptedMessage = jsonWithGrantId?["encrypted_message"] as? String
                let authGrantId = jsonWithGrantId?["authorization_grant_id"] as? String
                let data = Data(base64Encoded: encryptedMessage!)
                
                let entry = try self.keyStorage.loadKeyEntry(withName: identity)
                let privateKey = self.crypto.importPrivateKey(from: entry.value)
                
                let decodedMessage = try self.crypto.decrypt(data!, with: privateKey!)
                let importedPublicKey = self.crypto.importPublicKey(from: Data(base64Encoded: self.AuthPublicKey)!)
                
                let newEncryptedMessage = try self.crypto.encrypt(decodedMessage, for: [importedPublicKey!])
                let message = newEncryptedMessage.base64EncodedString()
                
                let requestForCode = try ServiceRequest(url: URL(string: "https://auth.virgilsecurity.com/v4/authorization-grant/" + authGrantId! + "/actions/acknowledge")!, method: ServiceRequest.Method.post, headers: ["Content-Type":"application/json"], params: ["encrypted_message": message])
                
                let responseWithCode = try self.connection.send(requestForCode)
                
                let jsonWithCode = try JSONSerialization.jsonObject(with: responseWithCode.body!, options: []) as? [String: Any]
                
                let code = jsonWithCode?["code"] as? String
                
                let requestForVirgilToken = try ServiceRequest(url: URL(string: "https://auth.virgilsecurity.com/v4/authorization/actions/obtain-access-token")!, method: ServiceRequest.Method.post, headers: ["Content-Type":"application/json"], params: ["grant_type": "access_code", "code": code])
                
                let responseWithVirgilToken = try self.connection.send(requestForVirgilToken)
                
                let jsonWithVirgilToken = try JSONSerialization.jsonObject(with: responseWithVirgilToken.body!, options: []) as? [String: Any]
                let access_token = jsonWithVirgilToken?["access_token"] as? String
                
                return access_token!
            } catch {
                Log.error("Error while getting virgil token")
                return String()
            }
    }
}
