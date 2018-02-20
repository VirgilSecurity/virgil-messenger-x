//
//  CoreDataHelper+Channel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import CoreData

extension CoreDataHelper {
    func createChannel(withName name: String, card: String) -> Channel? {
        guard let account = self.currentAccount else {
            Log.error("Core Data: nil account")
            return nil
        }

        guard let entity = NSEntityDescription.entity(forEntityName: Entities.channel.rawValue, in: self.managedContext) else {
            Log.error("Core Data: entity not found: " + Entities.channel.rawValue)
            return nil
        }

        let channel = Channel(entity: entity, insertInto: self.managedContext)

        channel.name = name
        channel.card = card
        channel.numColorPair = Int32(arc4random_uniform(UInt32(UIConstants.colorPairs.count)))

        let channels = account.mutableOrderedSetValue(forKey: Keys.channel.rawValue)
        channels.add(channel)

        Log.debug("Core Data: new channel added. Count: \(channels.count)")
        self.appDelegate.saveContext()

        return channel
    }

    func loadChannel(withName username: String) -> Bool {
        if let channel = self.getChannel(withName: username) {
            self.setCurrent(channel: channel)
            return true
        }
        return false
    }

    func getChannel(withName username: String) -> Channel? {
        guard let account = self.currentAccount, let channels = account.channel else {
            Log.error("Core Data: nil account core data")
            return nil
        }

        for channel in channels {
            guard let channel = channel as? Channel, let name = channel.name  else {
                Log.error("Core Data: can't get account channel")
                return nil
            }
            Log.debug("Core Data name: " + name)
            if name == username {
                Log.debug("Core Data: found channel in core data: " + name)
                return channel
            }
        }
        Log.error("Core Data: channel not found")
        return nil
    }

    func deleteChannel(withName username: String) {
        self.queue.async {
            guard let account = self.currentAccount, let channels = account.channel else {
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
}
