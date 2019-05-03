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

    public let virgilAuthorizer: VirgilAuthorizer

    private var queue: DispatchQueue?

    public init() {
        self.virgilAuthorizer = try! VirgilAuthorizer()
    }

    public func signIn() throws {
        guard let identity = UserDefaults.standard.string(forKey: UserAuthorizer.UserDefaultsIdentityKey), !identity.isEmpty else {
            throw UserAuthorizerError.noIdentityAtDefaults
        }

        try CoreDataHelper.shared.loadAccount(withIdentity: identity)

        try self.virgilAuthorizer.signIn(identity: identity)
    }

    public func signIn(identity: String) throws {
        try CoreDataHelper.shared.loadAccount(withIdentity: identity)

        try self.virgilAuthorizer.signIn(identity: identity)

        UserDefaults.standard.set(identity, forKey: UserAuthorizer.UserDefaultsIdentityKey)
    }

   public func signUp(identity: String, completion: @escaping (Error?) -> Void) {
        self.queue = DispatchQueue(label: "UserAuthorizerQueue")

        self.queue!.async {
            do {
                _ = try self.virgilAuthorizer.signUp(identity: identity)

                try CoreDataHelper.shared.createAccount(withIdentity: identity)

                UserDefaults.standard.set(identity, forKey: UserAuthorizer.UserDefaultsIdentityKey)

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    public func logOut() {
        UserDefaults.standard.set(nil, forKey: UserAuthorizer.UserDefaultsIdentityKey)

        CoreDataHelper.shared.deleteAccount()

        self.virgilAuthorizer.logOut(identity: TwilioHelper.shared.username)
    }
}

