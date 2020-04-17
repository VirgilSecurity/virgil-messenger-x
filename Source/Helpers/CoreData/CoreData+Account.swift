//
//  CoreData+Account.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import CoreData
import VirgilSDK

extension CoreData {
    func createAccount(withIdentity identity: String) throws {
        let account = try Account(identity: identity, managedContext: self.managedContext)

        self.append(account: account)
        self.setCurrent(account: account)

        try self.saveContext()
    }

    func loadAccount(withIdentity identity: String) throws {
        guard let account = self.accounts.first(where: { $0.identity == identity }) else {
            throw UserFriendlyError.noUserOnDevice
        }

        self.setCurrent(account: account)
    }

    func getCurrentAccount() throws -> Account {
        guard let account = self.currentAccount else {
            throw Error.nilCurrentAccount
        }

        return account
    }

    func setSendReadReceipts(to newValue: Bool) throws {
        let account = try self.getCurrentAccount()

        account.sendReadReceipts = newValue

        try self.saveContext()
    }

    func deleteAccount() throws {
        let account = try self.getCurrentAccount()

        try account.channels.forEach { try self.delete(channel: $0) }

        self.managedContext.delete(account)

        try self.saveContext()

        try self.reloadData()
    }
}
