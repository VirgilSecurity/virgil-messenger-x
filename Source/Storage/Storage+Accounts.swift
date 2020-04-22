//
//  Storage+Accounts.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/22/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

extension Storage {
    func createAccount(withIdentity identity: String) throws -> Account {
        let account = try Storage.Account(identity: identity, managedContext: self.managedContext)

        self.append(account: account)
        self.setCurrent(account: account)

        try self.saveContext()

        return account
    }

    func loadAccount(withIdentity identity: String) throws -> Account {
        guard let account = self.accounts.first(where: { $0.identity == identity }) else {
            throw UserFriendlyError.noUserOnDevice
        }

        self.setCurrent(account: account)

        return account
    }

    func getCurrentAccount() throws -> Storage.Account {
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
