//
//  UserAuthorizer.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/14/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import Foundation

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

        // FIXME
        guard Storage.shared.currentAccount == nil else {
            Log.debug("Skipping signing in. User is already signed in")
            return
        }

        let account = try Storage.shared.loadAccount(withIdentity: identity)

        try self.virgilAuthorizer.signIn(identity: identity)

        UnreadManager.shared.update()

        CallManager.shared.set(account: account)

        Ejabberd.shared.startInitializing(identity: identity)
    }

    public func signIn(identity: String) throws {
        let account = try Storage.shared.loadAccount(withIdentity: identity)

        try self.virgilAuthorizer.signIn(identity: identity)

        SharedDefaults.shared.set(identity: identity)

        UnreadManager.shared.update()

        CallManager.shared.set(account: account)

        Ejabberd.shared.startInitializing(identity: identity)
    }

   public func signUp(identity: String, completion: @escaping (Error?) -> Void) {
        DispatchQueue(label: "UserAuthorizer").async {
            do {
                try self.virgilAuthorizer.signUp(identity: identity)

                let account = try Storage.shared.createAccount(withIdentity: identity)

                SharedDefaults.shared.set(identity: identity)

                CallManager.shared.set(account: account)

                Ejabberd.shared.startInitializing(identity: identity)

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

                Storage.shared.resetState()

                SharedDefaults.shared.reset(.identity)
                UnreadManager.shared.reset()

                CallManager.shared.resetAccount()

                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }

    public func deleteAccount() throws {
        SharedDefaults.shared.reset(.identity)
        UnreadManager.shared.reset()

        try Storage.shared.deleteAccount()
        Storage.shared.resetState()

        try Ejabberd.shared.disconect()

        self.virgilAuthorizer.logOut()
    }
}
