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
        guard let entity = NSEntityDescription.entity(forEntityName: Entities.account.rawValue, in: self.managedContext) else {
            throw CoreDataHelperError.entityNotFound
        }

        let account = Account(entity: entity, insertInto: self.managedContext)

        account.identity = identity
        account.setupColorPair()

        self.append(account: account)
        self.setCurrent(account: account)

        self.appDelegate.saveContext()
    }

    func loadAccount(withIdentity username: String) throws {
        let account = self.accounts.first { $0.identity == username }

        guard let accountToLoad = account else {
            throw UserFriendlyError.noUserOnDevice
        }

        self.setCurrent(account: accountToLoad)
    }

    func getAccount(withIdentity username: String) -> Account? {
        return accounts.first { $0.identity == username }
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
