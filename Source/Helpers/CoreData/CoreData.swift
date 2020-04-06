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

    private var mediaStorage: FileMediaStorage?

    let managedContext: NSManagedObjectContext

    public static let dbName = "VirgilMessenger-5"

    let persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: CoreData.dbName)

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                Log.error(error, message: "Load persistent store failed")

                fatalError()
            }
        }

        return container
    }()

    public enum Error: Int, LocalizedError {
        case nilCurrentAccount = 1
        case nilCurrentChannel = 2
        case entityNotFound = 3
        case channelNotFound = 4
        case invalidChannel = 5
        case invalidMessage = 6
        case accountNotFound = 7
        case missingVirgilGroup = 8
        case exportBaseMessageForbidden = 9
        case nilMediaStorage = 10
        case messageWithIdNotFound = 11
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

        try self.mediaStorage?.reset()

        try self.reloadData()
    }

    internal func getMediaStorage() throws -> FileMediaStorage {
        guard let storage = self.mediaStorage else {
            throw Error.nilMediaStorage
        }

        return storage
    }

    func setCurrent(account: Account) {
        self.currentAccount = account

        self.mediaStorage = FileMediaStorage(identity: account.identity)
    }

    func setCurrent(channel: Channel) {
        self.currentChannel = channel
        Log.debug("Core Data channel selected: \(String(describing: self.currentChannel?.name))")
    }

    func append(account: Account) {
        self.accounts.append(account)
    }

    func deselectChannel(_ channel: Channel? = CoreData.shared.currentChannel) {
        if self.currentChannel == channel {
            self.currentChannel = nil
            Log.debug("Core Data channel deselected: \(String(describing: self.currentChannel?.name))")
        } else {
            Log.debug("Core Data channel deselected failed: \(String(describing: self.currentChannel?.name)) is not the current channel")
        }
    }

    func resetState() {
        self.currentAccount = nil
        self.deselectChannel()
        self.mediaStorage = nil
    }
}
