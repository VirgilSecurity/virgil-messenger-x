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
    public let virgilAuthorizer: VirgilAuthorizer

    public init() {
        self.virgilAuthorizer = try! VirgilAuthorizer()
    }

    public func signIn() throws {
        guard let identity = IdentityDefaults.shared.get() else {
            throw UserAuthorizerError.noIdentityAtDefaults
        }

        try Storage.shared.loadAccount(withIdentity: identity)

        try self.virgilAuthorizer.signIn(identity: identity)
    }

    public func signIn(identity: String) throws {
        try Storage.shared.loadAccount(withIdentity: identity)

        try self.virgilAuthorizer.signIn(identity: identity)

        IdentityDefaults.shared.set(identity: identity)
    }

   public func signUp(identity: String, completion: @escaping (Error?) -> Void) {
        DispatchQueue(label: "UserAuthorizer").async {
            do {
                _ = try self.virgilAuthorizer.signUp(identity: identity)

                try Storage.shared.createAccount(withIdentity: identity)

                IdentityDefaults.shared.set(identity: identity)

                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }

    public func logOut(completion: @escaping (Error?) -> Void) {
        DispatchQueue(label: "UserAuthorizer").async {
            do {
                try Ejabberd.shared.deregisterFromNotifications()

                try Ejabberd.shared.disconect()

                Configurator.reset()
                Storage.shared.resetState()

                IdentityDefaults.shared.reset()

                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }

    public func deleteAccount() throws {
        IdentityDefaults.shared.reset()

        Configurator.reset()

        try Storage.shared.deleteAccount()
        Storage.shared.resetState()
        try Ejabberd.shared.disconect()

        self.virgilAuthorizer.logOut()
    }
}

