//
//  UserAuthorizer.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/14/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import Foundation
import VirgilSDK

enum UserAuthorizerError: String, Error {
    case gettingJwtFailed
    case noIdentityAtDefaults
}

public class UserAuthorizer {
    public static let UserDefaultsIdentityKey = "last_username"

    private let queue = DispatchQueue(label: "UserAuthorizerQueue")

    func signIn(completion: @escaping(Error?) -> Void) {
        self.queue.async {
            do {
                guard let identity = UserDefaults.standard.string(forKey: UserAuthorizer.UserDefaultsIdentityKey), !identity.isEmpty else {
                    throw UserAuthorizerError.noIdentityAtDefaults
                }

                try CoreDataHelper.sharedInstance.loadAccount(withIdentity: identity)

                let exportedCard = try CoreDataHelper.sharedInstance.getAccountCard()

                try VirgilHelper.sharedInstance.signIn(identity: identity, card: exportedCard).startSync().getResult()

                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }

    func signIn(identity: String, completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                try CoreDataHelper.sharedInstance.loadAccount(withIdentity: identity)
                let exportedCard = try CoreDataHelper.sharedInstance.getAccountCard()

                try VirgilHelper.sharedInstance.signIn(identity: identity, card: exportedCard).startSync().getResult()

                UserDefaults.standard.set(identity, forKey: UserAuthorizer.UserDefaultsIdentityKey)

                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch CoreDataHelperError.accountNotFound {
                DispatchQueue.main.async {
                    completion(VirgilHelper.UserFriendlyError.noUserOnDevice)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }

    func signUp(identity: String, completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                let exportedCard = try VirgilHelper.sharedInstance.signUp(identity: identity).startSync().getResult()

                try CoreDataHelper.sharedInstance.createAccount(withIdentity: identity, exportedCard: exportedCard)

                UserDefaults.standard.set(identity, forKey: UserAuthorizer.UserDefaultsIdentityKey)

                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }
}

