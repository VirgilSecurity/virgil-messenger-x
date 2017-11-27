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

class CoreDataHelper {
    
    static private(set) var sharedInstance: CoreDataHelper!
    
    private let queue: DispatchQueue
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private let managedContext: NSManagedObjectContext
    private(set) var accounts: [Account] = []
    private var myAccount: Account?
    private(set) var selectedChannel: Channel?
    
    enum Entities: String {
        case Account   = "Account"
        case Channel   = "Channel"
        case Message   = "Message"
    }
    
    enum Keys: String {
        case account   = "account"
        case channel   = "channel"
        case message   = "message"
        
        case identity   = "identity"
        case name       = "name"
        case body       = "body"
        case isIncoming = "isIncoming"
    }
    
    static func initialize() {
        sharedInstance = CoreDataHelper()
    }
    
    private init() {
        managedContext = self.appDelegate.persistentContainer.viewContext
        self.queue = DispatchQueue(label: "core-data-help-queue")
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
    
    func loadAccount(withIdentity username: String) -> Bool {
        Log.debug("Core Data: Search for " + username)
        for account in CoreDataHelper.sharedInstance.accounts {
            if let identity = account.identity, identity == username {
                self.myAccount = account
                Log.debug("Core Data: found account: " + identity)
                let channels = account.channel
                Log.debug("Core Data: it has " + String(describing: channels?.count) + " channels")
                return true
            }
        }
         Log.debug("Core Data: Searching for account ended")
        return false
    }
    
    func createAccount(withIdentity identity: String, exportedCard: String) {
        self.queue.async {
            guard let entity = NSEntityDescription.entity(forEntityName: Entities.Account.rawValue, in: self.managedContext) else {
                Log.error("Core Data: entity not found: " + Entities.Account.rawValue)
                return
            }
            
            let account = Account(entity: entity, insertInto: self.managedContext)
            
            account.identity = identity
            account.card = exportedCard
            
            self.accounts.append(account)
            self.myAccount = account
            
            Log.debug("Core Data: account created")
            
            self.appDelegate.saveContext()
        }
    }
    
    func getAccountCard() -> String? {
        if let account = myAccount, let card = account.card {
            return card
        }
        else {
            Log.error("Core Data: nil account found")
            return nil
        }
    }
    
    func createChannel(withName name: String, card: String) {
        self.queue.async {
            guard let account = self.myAccount else {
                Log.error("Core Data: nil account")
                return
            }
            
            guard let entity = NSEntityDescription.entity(forEntityName: Entities.Channel.rawValue, in: self.managedContext) else {
                Log.error("Core Data: entity not found: " + Entities.Channel.rawValue)
                return
            }
            
            let channel = Channel(entity: entity, insertInto: self.managedContext)
            
            channel.name = name
            channel.card = card
            
            let channels = account.mutableSetValue(forKey: Keys.channel.rawValue)
            channels.add(channel)
            
            Log.debug("Core Data: new channel added. Count: \(channels.count)")
            self.appDelegate.saveContext()
        }
    }
    
    func createMessage(withBody body: String, isIncoming: Bool, date: Date) {
        self.queue.async {
            guard let channel = self.selectedChannel else {
                Log.error("Core Data: nil selected channel")
                return
            }
            
            guard let entity = NSEntityDescription.entity(forEntityName: Entities.Message.rawValue, in: self.managedContext) else {
                Log.error("Core Data: entity not found: " + Entities.Message.rawValue)
                return
            }
            
            let message = Message(entity: entity, insertInto: self.managedContext)
            
            let encryptedBody =  try? VirgilHelper.sharedInstance.encrypt(text: body)
            message.body = encryptedBody ?? "Error encrypting message"
            message.isIncoming = isIncoming
            message.date = date
            
            let messages = channel.mutableOrderedSetValue(forKey: Keys.message.rawValue)
            messages.add(message)
            
            Log.debug("Core Data: new message added. Count: \(messages.count)")
            self.appDelegate.saveContext()
        }
    }
    
    func loadChannel(withName username: String) -> Bool {
        guard let account = self.myAccount, let channels = account.channel else {
            Log.error("Core Data: nil account core data")
            return false
        }
        
        for channel in channels {
            guard let channel = channel as? Channel, let name = channel.name  else {
                Log.error("Core Data: can't get account channel")
                return false
            }
            Log.debug("Core Data name: " + name)
            if name == username {
                Log.debug("Core Data: found channel in core data: " + name)
                self.selectedChannel = channel
                return true
            }
        }
        Log.error("Core Data: channel not found")
        return false
    }
    
    func deleteAccount() {
        guard let account = self.myAccount else {
            Log.error("Core Data: nil account")
            return
        }

        self.managedContext.delete(account)
        Log.debug("Core Data: account deleted")
    
        self.appDelegate.saveContext()
    }
    
    func deleteChannel(withName username: String) {
        self.queue.async {
            guard let account = self.myAccount, let channels = account.channel else {
                Log.error("Core Data: nil account")
                return
            }
            
            for channel in channels {
                guard let channel = channel as? Channel, let name = channel.name else {
                    Log.error("Core Data: can't get account channels")
                    return
                }
                
                Log.debug("Core Data name: " + name)
                if name == username {
                    Log.debug("Core Data: found channel in core data: " + name)
                    self.managedContext.delete(channel)
                    Log.debug("Core Data: channel deleted")
                    return
                }
            }
            Log.error("Core Data: channel not found")
            self.appDelegate.saveContext()
        }
    }
    
    private func fetch() -> [Account]? {
        let fetchRequest =
            NSFetchRequest<NSManagedObject>(entityName: Entities.Account.rawValue)

        do {
            let accounts = try managedContext.fetch(fetchRequest) as? [Account]
            return accounts
        } catch let error as NSError {
            Log.error("Could not fetch. \(error), \(error.userInfo)")
            return nil
        }
    }
}
