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

enum CoreDataHelperError: String, Error {
    case accountNotFound
    case nilCurrentAccount
    case entityNotFound
    case entityCorrupted
}

class CoreDataHelper {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let managedContext: NSManagedObjectContext

    private(set) static var shared: CoreDataHelper = CoreDataHelper()
    private(set) var accounts: [Account] = []
    private(set) var currentChannel: Channel?
    private(set) var currentAccount: Account?

    enum Entities: String {
        case account = "Account"
        case channel = "Channel"
        case message = "Message"
    }

    enum Keys: String {
        case account
        case channel
        case message
        case identity
        case name
        case body
        case isIncoming
        case type
    }

    let lastMessageIdentifier = [
        MessageType.photo.rawValue: "Photo",
        MessageType.audio.rawValue: "Voice Message"
    ]

    private init() {
        self.managedContext = self.appDelegate.persistentContainer.viewContext

        guard let accounts = self.fetch() else {
            Log.error("Core Data: fetch error")
            return
        }

        self.accounts = accounts
        Log.debug("Core Data: accounts fetched. Count: \(self.accounts.count)")
        
        for account in self.accounts {
            let identity = account.identity ?? "not found"
            Log.debug(identity)
        }
    }

    func reloadData() {
        guard let accounts = self.fetch() else {
            Log.error("Core Data: fetch error")
            return
        }
        self.accounts = accounts
    }

    private func fetch() -> [Account]? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: Entities.account.rawValue)

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
