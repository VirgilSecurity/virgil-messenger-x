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
    func makeCreateGroupChannelOperation(name: String,
                                         serviceMessage: Data? = nil,
                                         members: [String],
                                         cards: [Card]? = nil) -> CallbackOperation<Void> {
        return CallbackOperation<Void> { operation, completion in
            do {
                let cards: [Card] = try cards ?? operation.findDependencyResult()

                let channel = try self.createChannel(type: .group, name: name, cards: cards)

                if let serviceMessage = serviceMessage {
                    try self.saveServiceMessage(serviceMessage, to: channel, type: .startGroup)
                }

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
                let cards: [Card] = try operation.findDependencyResult()

                _ = try self.createChannel(type: .single, name: identity, cards: cards)

                completion((), nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }

    private func createChannel(type: ChannelType, name: String, cards: [Card]) throws -> Channel {
        guard let account = self.currentAccount else {
            throw CoreDataHelperError.nilCurrentAccount
        }

        let channel = try Channel(name: name, type: type, cards: cards, managedContext: self.managedContext)

        let channels = account.mutableOrderedSetValue(forKey: Account.ChannelsKey)
        channels.add(channel)

        self.appDelegate.saveContext()

        return channel
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
