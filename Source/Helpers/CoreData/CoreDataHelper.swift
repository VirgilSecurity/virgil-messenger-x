//
//  CoreDataHelper.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 11/9/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit
import Foundation
import CoreData

enum CoreDataHelperError: Int, Error {
    case accountNotFound = 1
    case nilCurrentAccount = 2
    case nilCurrentChannel = 3
    case entityNotFound = 4
    case entityCorrupted = 5
}

class CoreDataHelper {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let managedContext: NSManagedObjectContext

    private(set) static var shared: CoreDataHelper = CoreDataHelper()
    private(set) var accounts: [Account] = []
    private(set) var currentChannel: Channel?
    private(set) var currentAccount: Account?

    private init() {
        self.managedContext = self.appDelegate.persistentContainer.viewContext

        guard let accounts = self.fetch() else {
            Log.error("Core Data: fetch error")
            return
        }

        self.accounts = accounts
    }

    func reloadData() {
        guard let accounts = self.fetch() else {
            Log.error("Core Data: fetch error")
            return
        }

        self.accounts = accounts
    }

    private func fetch() -> [Account]? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: Account.EntityName)

        do {
            let accounts = try managedContext.fetch(fetchRequest) as? [Account]
            return accounts
        } catch let error as NSError {
            Log.error("Could not fetch. \(error), \(error.userInfo)")
            return nil
        }
    }

    func setCurrent(account: Account) {
        self.currentAccount = account
    }

    func setCurrent(channel: Channel) {
        self.currentChannel = channel
    }

    func append(account: Account) {
        self.accounts.append(account)
    }
}
