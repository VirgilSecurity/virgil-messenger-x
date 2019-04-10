//
//  CoreDataHelper+Account.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import CoreData

extension CoreDataHelper {
    func createAccount(withIdentity identity: String, card: String) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: Entities.account.rawValue, in: self.managedContext) else {
            throw CoreDataHelperError.entityNotFound
        }

        let account = Account(entity: entity, insertInto: self.managedContext)

        account.identity = identity
        account.card = card
        account.numColorPair = Int32(arc4random_uniform(UInt32(UIConstants.colorPairs.count)))

        self.append(account: account)
        self.setCurrent(account: account)

        self.appDelegate.saveContext()
    }

    func loadAccount(withIdentity username: String) throws -> String {
        let account = self.accounts.first { $0.identity == username }

        guard let accountToLoad = account else {
            throw UserFriendlyError.noUserOnDevice
        }

        guard let card = accountToLoad.card else {
            throw CoreDataHelperError.entityCorrupted
        }

        self.setCurrent(account: accountToLoad)

        self.getChannels().forEach { self.setLastMessage(for: $0) }

        return card
    }

    func getAccount(withIdentity username: String) -> Account? {
        for account in self.accounts {
            if let identity = account.identity, identity == username {
                return account
            }
        }
        return nil
    }

    func deleteAccount() {
        guard let account = self.currentAccount else {
            Log.error("Core Data: missing account")
            return
        }

        self.managedContext.delete(account)
        Log.debug("Core Data: account deleted")

        self.appDelegate.saveContext()

        self.reloadData()
    }
}
