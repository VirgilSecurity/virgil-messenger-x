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
        guard let identity: String = SharedDefaults.shared.get(.identity) else {
            throw UserAuthorizerError.noIdentityAtDefaults
        }

        try CoreData.shared.loadAccount(withIdentity: identity)

        try self.virgilAuthorizer.signIn(identity: identity)

        UnreadManager.shared.update()
    }

    public func signIn(identity: String) throws {
        try CoreData.shared.loadAccount(withIdentity: identity)

        try self.virgilAuthorizer.signIn(identity: identity)

        let account = CoreData.shared.currentAccount!

        SharedDefaults.shared.set(identity: identity,
                                  ejabberdHost: account.ejabberdHost,
                                  pushHost: account.pushHost,
                                  backendHost: account.backendHost)

        UnreadManager.shared.update()
    }

    public func signUp(identity: String,
                       ejabberdHost: String,
                       pushHost: String,
                       backendHost: String,
                       completion: @escaping (Error?) -> Void) {
        DispatchQueue(label: "UserAuthorizer").async {
            do {
                try self.virgilAuthorizer.signUp(identity: identity, backendHost: backendHost)

                try CoreData.shared.createAccount(withIdentity: identity,
                                                  ejabberdHost: ejabberdHost,
                                                  pushHost: pushHost,
                                                  backendHost: backendHost)

                SharedDefaults.shared.set(identity: identity,
                                          ejabberdHost: ejabberdHost,
                                          pushHost: pushHost,
                                          backendHost: backendHost)

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
                CoreData.shared.resetState()

                SharedDefaults.shared.reset()
                UnreadManager.shared.reset()

                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }

    public func deleteAccount() throws {
        SharedDefaults.shared.reset()
        UnreadManager.shared.reset()

        Configurator.reset()

        try CoreData.shared.deleteAccount()
        CoreData.shared.resetState()
        try Ejabberd.shared.disconect()

        self.virgilAuthorizer.logOut()
    }
}
