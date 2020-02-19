//
//  CoreData.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 11/9/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import CoreData

class CoreData {
    private(set) static var shared: CoreData = CoreData()
    private(set) var accounts: [Account] = []
    private(set) var currentChannel: Channel?
    private(set) var currentAccount: Account?

    private let queue = DispatchQueue(label: "CoreData")

    let managedContext: NSManagedObjectContext

    public static let dbName = "VirgilMessenger-5"

    let persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: CoreData.dbName)

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                Log.error("Load persistent store failed: \(error.localizedDescription)")

                fatalError()
            }
        }

        return container
    }()

    public enum Error: Int, Swift.Error {
        case nilCurrentAccount = 1
        case nilCurrentChannel = 2
        case entityNotFound = 3
        case channelNotFound = 4
        case invalidChannel = 5
        case invalidMessage = 6
        case accountNotFound = 7
        case missingVirgilGroup = 8
    }

    private init() {
        self.managedContext = self.persistentContainer.viewContext

        try? self.reloadData()
    }

    func saveContext() throws {
        try self.queue.sync {
            if self.managedContext.hasChanges {
                try self.managedContext.save()
            }
        }
    }

    func reloadData() throws {
        self.accounts = try self.fetch()
    }

    private func fetch() throws -> [Account] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: Account.EntityName)

        let accounts = try self.managedContext.fetch(fetchRequest) as? [Account]

        return accounts ?? []
    }

    public func clearStorage() throws {
        Log.debug("Cleaning CoreData storage")

        for account in self.accounts {
            try account.channels.forEach { try self.delete(channel: $0) }

            self.managedContext.delete(account)
        }

        try self.saveContext()

        try self.reloadData()
    }

    func setCurrent(account: Account) {
        self.currentAccount = account
    }

    func setCurrent(channel: Channel) {
        self.currentChannel = channel
        Log.debug("Core Data channel selected: \(String(describing: self.currentChannel?.name))")
    }

    func append(account: Account) {
        self.accounts.append(account)
    }

    func deselectChannel() {
        Log.debug("Core Data channel deselected: \(String(describing: self.currentChannel?.name))")
        self.currentChannel = nil
    }

    func resetState() {
        self.currentAccount = nil
        self.deselectChannel()
    }
}
