//
//  UserAuthorizer.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/14/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK

enum UserAuthorizerError: String, Error {
    case noIdentityAtDefaults
}

public class UserAuthorizer {
    public static let UserDefaultsIdentityKey = "last_username"

    public let virgilAuthorizer: VirgilAuthorizer

    public init() {
        self.virgilAuthorizer = try! VirgilAuthorizer()
    }

    public func signIn() throws {
        guard let identity = UserDefaults.standard.string(forKey: UserAuthorizer.UserDefaultsIdentityKey), !identity.isEmpty else {
            throw UserAuthorizerError.noIdentityAtDefaults
        }

        try CoreData.shared.loadAccount(withIdentity: identity)

        try self.virgilAuthorizer.signIn(identity: identity)
    }

    public func signIn(identity: String) throws {
        try CoreData.shared.loadAccount(withIdentity: identity)

        try self.virgilAuthorizer.signIn(identity: identity)

        UserDefaults.standard.set(identity, forKey: UserAuthorizer.UserDefaultsIdentityKey)
    }

   public func signUp(identity: String, completion: @escaping (Error?) -> Void) {
        DispatchQueue(label: "UserAuthorizer").async {
            do {
                _ = try self.virgilAuthorizer.signUp(identity: identity)

                try CoreData.shared.createAccount(withIdentity: identity)

                UserDefaults.standard.set(identity, forKey: UserAuthorizer.UserDefaultsIdentityKey)

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    public func logOut(completion: @escaping (Error?) -> Void) {
        DispatchQueue(label: "UserAuthorizer").async {
            do {
                if let token = Twilio.updatedPushToken {
                    try Twilio.shared.deregister(withNotificationToken: token).startSync().get()
                }

                Configurator.reset()

                UserDefaults.standard.set(nil, forKey: UserAuthorizer.UserDefaultsIdentityKey)

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    public func deleteAccount() throws {
        UserDefaults.standard.set(nil, forKey: UserAuthorizer.UserDefaultsIdentityKey)

        Configurator.reset()

        try CoreData.shared.deleteAccount()

        self.virgilAuthorizer.logOut(identity: Twilio.shared.identity)
    }
}

