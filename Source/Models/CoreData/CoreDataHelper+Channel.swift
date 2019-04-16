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
    func makeCreateGroupChannelOperation(name: String, members: [String], cards: [String]? = nil) -> CallbackOperation<Void> {
        return CallbackOperation<Void> { operation, completion in
            do {
                let cards: [String] = try cards ?? operation.findDependencyResult()

                try self.createChannel(type: .group, name: name, cards: cards)

                completion((), nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }

    func makeCreateSingleChannelOperation(with identity: String) -> CallbackOperation<Void> {
        return CallbackOperation<Void> { operation, completion in
            do {
                let cards: [String] = try operation.findDependencyResult()

                try self.createChannel(type: .single, name: identity, cards: cards)

                completion((), nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }

    func createChannel(type: ChannelType, name: String, cards: [String]) throws {
        guard let account = self.currentAccount else {
            throw CoreDataHelperError.nilCurrentAccount
        }

        guard let entity = NSEntityDescription.entity(forEntityName: Entities.channel.rawValue,
                                                      in: self.managedContext) else {
            throw CoreDataHelperError.entityNotFound
        }

        let channel = Channel(entity: entity, insertInto: self.managedContext)

        channel.name = name
        channel.cards = cards
        channel.type = type
        channel.setupColorPair()

        let channels = account.mutableOrderedSetValue(forKey: Keys.channels.rawValue)
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
        let channels = self.getChannels()

        return channels.first { $0.name == username }
    }

    func getChannels() -> [Channel] {
        return self.currentAccount?.channels ?? []
    }

    func getSingleChannels() -> [Channel] {
        guard let channels = self.currentAccount?.channels else {
            Log.error("Core Data: missing current account or channels")
            return []
        }

        let singleChannels = channels.filter { $0.type == .single }
        
        return singleChannels
    }
}
