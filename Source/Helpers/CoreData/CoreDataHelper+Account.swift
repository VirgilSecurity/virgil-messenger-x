//
//  CoreDataHelper+Account.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import CoreData
import VirgilSDK

extension CoreDataHelper {
    func createAccount(withIdentity identity: String) throws {
        let account = try Account(identity: identity, managedContext: self.managedContext)

        self.append(account: account)
        self.setCurrent(account: account)

        try self.saveContext()
    }

    func loadAccount(withIdentity identity: String) throws {
        guard let account = self.getAccount(withIdentity: identity) else {
            throw UserFriendlyError.noUserOnDevice
        }

        self.setCurrent(account: account)
    }

    func getAccount(withIdentity username: String) -> Account? {
        return self.accounts.first { $0.identity == username }
    }

    func deleteAccount() throws {
        guard let account = self.currentAccount else {
            fatalError("Current account is not set")
        }

        try account.channels.forEach { try self.delete(channel: $0) }

        self.managedContext.delete(account)

        try self.saveContext()

        try self.reloadData()
    }
}
