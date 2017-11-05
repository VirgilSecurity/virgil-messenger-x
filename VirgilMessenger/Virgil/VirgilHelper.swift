//
//  VirgilHelper.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 11/4/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import VirgilSDK

class VirgilHelper {
    
    static let sharedInstance = VirgilHelper()
    private let crypto: VSSCrypto
    private let keyStorage: VSSKeyStorage
    private let queue: DispatchQueue
    private let connection: ServiceConnection
    
    private let VirgilAccessToken = "AT.6968c649d331798cbbb757c2cfcae6475416ef958b41d3feddd103dee22a970b"
    private let AuthPublicKey = "MCowBQYDK2VwAyEAHQe7Uf+sUQASm3eGqaqMIfrbHKU9gKUnDg7AuVzf0Z0="
    
    private init() {
        self.crypto = VSSCrypto()
        self.keyStorage = VSSKeyStorage()
        self.queue = DispatchQueue(label: "virgil-help-queue")
        self.connection = ServiceConnection()
    }
    
    func signIn(identity: String, completion: @escaping (Error?) -> ()) {
        self.queue.async {
            Log.debug("Signing in")
            let serviceConfig = VSSServiceConfig(token: self.VirgilAccessToken)
            serviceConfig.cardsServiceURL = URL(string: "https://cards.virgilsecurity.com/v4/")!
            serviceConfig.cardsServiceROURL = URL(string: "https://cards-ro.virgilsecurity.com/v4/")!
        
            let client = VSSClient(serviceConfig: serviceConfig)
            
            let criteria = VSSSearchCardsCriteria(identity: identity)
            
            client.searchCards(using: criteria, completion: { (cards, error) in
                
                guard error == nil else {
                    Log.error("Error while signing in: searching cards error")
                    completion(NSError())
                    return
                }
                guard cards != nil else {
                    Log.error("Error while signing in: no Virgil card found")
                    completion(NSError())
                    return
                }
                
                self.getTwilioToken(withCardId: cards![0].identifier, identity: identity) { token, error in
                    if error != nil {
                        completion(error)
                    }
                    else {
                        TwilioHelper.authorize(username: identity, device: "iPhone")
                        TwilioHelper.sharedInstance.initialize(token: token!) { error in
                            guard error == nil else {
                                completion(NSError())
                                return
                            }
                            completion(nil)
                        }
                    }
                }
            })
        }
    }
    
    func signUp(identity: String, identityType: String = "name", completion: @escaping (Error?) -> ()) {
        self.queue.async {
            Log.debug("Signing up")
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
                
                let keyEntry = VSSKeyEntry(name: identity, value: self.crypto.export(keyPair.privateKey, withPassword: nil))
                if self.keyStorage.existsKeyEntry(withName: identity) {
                    try self.keyStorage.deleteKeyEntry(withName: identity)
                }
                try self.keyStorage.store(keyEntry)
                
                self.getTwilioToken(withCardId: cardId, identity: identity) { token, error in
                    if error != nil {
                        completion(error)
                    }
                    else {
                        TwilioHelper.authorize(username: identity, device: "iPhone")
                        TwilioHelper.sharedInstance.initialize(token: token!) {error in
                            guard error == nil else {
                                completion(NSError())
                                return
                            }
                            completion(nil)
                        }
                    }
                }
                
            } catch {
                Log.error("Error while signing up: \(error.localizedDescription)")
                completion(error)
            }
        }
    }
    
    private func getTwilioToken(withCardId: String, identity: String, completion: @escaping (String?, Error?) -> ()) {
        do {
            let VirgilToken = getVirgilToken(withCardId: withCardId, identity: identity)
            
            guard VirgilToken != "" else {
                throw NSError()
            }
            
            let requestForTwilioToken = try ServiceRequest(url: URL(string: "https://twilio.virgilsecurity.com/v1/tokens/twilio")!, method: ServiceRequest.Method.get, headers: ["Authorization": VirgilToken])
            let responseWithTwilioToken = try connection.send(requestForTwilioToken)
            
            let twilioTokenJson = try! JSONSerialization.jsonObject(with: responseWithTwilioToken.body!, options: []) as? [String: Any]
            
            let twilioToken = twilioTokenJson?["twilioToken"] as? String
            
            completion(twilioToken, nil)
            
        } catch {
            Log.error("Error while getting twilio token")
            completion(nil, error)
        }
    }
    
    private func getVirgilToken(withCardId: String, identity: String) -> String {
        do {
            let requestForGrantId = try ServiceRequest(url: URL(string: "https://auth-twilio.virgilsecurity.com/v4/authorization-grant/actions/get-challenge-message")!, method: ServiceRequest.Method.post, headers: ["Content-Type":"application/json"], params: ["resource_owner_virgil_card_id" : withCardId])
            
            let responseWithGrantId =  try connection.send(requestForGrantId)
            
            let jsonWithGrantId = try JSONSerialization.jsonObject(with: responseWithGrantId.body!, options: []) as? [String: Any]
            let encryptedMessage = jsonWithGrantId?["encrypted_message"] as? String
            let authGrantId = jsonWithGrantId?["authorization_grant_id"] as? String
            let data = Data(base64Encoded: encryptedMessage!)
            
            let entry = try keyStorage.loadKeyEntry(withName: identity)
            let privateKey = crypto.importPrivateKey(from: entry.value)
            
            let decodedMessage = try crypto.decrypt(data!, with: privateKey!)
            let importedPublicKey = crypto.importPublicKey(from: Data(base64Encoded: AuthPublicKey)!)
            
            let newEncryptedMessage = try crypto.encrypt(decodedMessage, for: [importedPublicKey!])
            let message = newEncryptedMessage.base64EncodedString()
            
            let requestForCode = try ServiceRequest(url: URL(string: "https://auth.virgilsecurity.com/v4/authorization-grant/" + authGrantId! + "/actions/acknowledge")!, method: ServiceRequest.Method.post, headers: ["Content-Type":"application/json"], params: ["encrypted_message": message])
            
            let responseWithCode = try connection.send(requestForCode)
            
            let jsonWithCode = try JSONSerialization.jsonObject(with: responseWithCode.body!, options: []) as? [String: Any]
            
            let code = jsonWithCode?["code"] as? String
            
            let requestForVirgilToken = try ServiceRequest(url: URL(string: "https://auth.virgilsecurity.com/v4/authorization/actions/obtain-access-token")!, method: ServiceRequest.Method.post, headers: ["Content-Type":"application/json"], params: ["grant_type": "access_code", "code": code])
            
            let responseWithVirgilToken = try connection.send(requestForVirgilToken)
            
            let jsonWithVirgilToken = try JSONSerialization.jsonObject(with: responseWithVirgilToken.body!, options: []) as? [String: Any]
            let access_token = jsonWithVirgilToken?["access_token"] as? String
            
            let VirgilToken = "bearer " + access_token!
            return VirgilToken
        } catch {
            Log.error("Error while getting virgil token")
            return ""
        }
    }
}
