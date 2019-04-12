//
//  CoreDataHelper+Channel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import CoreData
import VirgilSDK

extension CoreDataHelper {
    func createChannel(identity: String) -> CallbackOperation<Void> {
        return CallbackOperation<Void> { operation, completion in
            do {
                let card: String = try operation.findDependencyResult()

                try self.createChannel(name: identity, cards: [card])

                completion((), nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }

    func createChannel(type: ChannelType = .single, name: String, cards: [String]) throws {
        guard let account = self.currentAccount else {
            throw CoreDataHelperError.nilCurrentAccount
        }

        guard let entity = NSEntityDescription.entity(forEntityName: Entities.channel.rawValue, in: self.managedContext) else {
            throw CoreDataHelperError.entityNotFound
        }

        let channel = Channel(entity: entity, insertInto: self.managedContext)

        channel.name = name
        channel.cards = cards
        channel.type = type.rawValue
        channel.numColorPair = Int32(arc4random_uniform(UInt32(UIConstants.colorPairs.count)))

        let channels = account.mutableOrderedSetValue(forKey: Keys.channel.rawValue)
        channels.add(channel)

        Log.debug("Core Data: new channel added. Count: \(channels.count)")
        self.appDelegate.saveContext()
    }

    func loadChannel(withName username: String) -> Channel? {
        guard let channel = self.getChannel(withName: username) else {
            return nil
        }

        self.setCurrent(channel: channel)

        return channel
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

    func deleteChannel(type typetoDelete: ChannelType, name nameToDelete: String) {
        guard let account = self.currentAccount, let channels = account.channel else {
            Log.error("Core Data: missing account")
            return
        }

        for channel in channels {
            guard let channel = channel as? Channel,
                let name = channel.name,
                let type = channel.type else {
                    Log.error("Core Data: can't get account channels")
                    return
            }

            Log.debug("Core Data name: " + name)
            if type == typetoDelete.rawValue, name == nameToDelete {
                Log.debug("Core Data: found channel in core data: " + name)
                self.managedContext.delete(channel)
                Log.debug("Core Data: channel deleted")
                return
            }
        }
        Log.error("Core Data: channel not found")
        self.appDelegate.saveContext()
    }

    func getChannels() -> [Channel] {
        guard let channels = self.currentAccount?.channel else {
            Log.error("Core Data: missing current account or channels")
            return []
        }

        // FIXME
        return channels.map { $0 as! Channel }
    }
}
