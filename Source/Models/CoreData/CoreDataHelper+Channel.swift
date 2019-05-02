//
//  CoreDataHelper+Channel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import CoreData
import VirgilSDK
import TwilioChatClient

extension CoreDataHelper {
    func makeCreateGroupChannelOperation(name: String,
                                         members: [String],
                                         cards: [Card]? = nil) -> CallbackOperation<Void> {
        return CallbackOperation<Void> { operation, completion in
            do {
                let cards: [Card] = try cards ?? operation.findDependencyResult()

                _ = try self.createChannel(type: .group, name: name, cards: cards)

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

    private func createChannel(type: ChannelType, name: String, cards: [Card], sessionId: Data? = nil) throws -> Channel {
        guard let account = self.currentAccount else {
            throw CoreDataHelperError.nilCurrentAccount
        }

        let channel = try Channel(name: name,
                                  type: type,
                                  account: account,
                                  cards: cards,
                                  sessionId: sessionId,
                                  managedContext: self.managedContext)

        self.appDelegate.saveContext()

        return channel
    }

    func setSessionId(_ sessionId: Data, for channel: Channel) {
        guard channel.sessionId != sessionId else {
            return
        }
        
        channel.sessionId = sessionId

        self.appDelegate.saveContext()
    }

    func loadChannel(withName username: String) -> Channel? {
        guard let channel = self.getChannel(withName: username) else {
            return nil
        }

        self.setCurrent(channel: channel)

        return channel
    }

    func getChannel(_ twilioChannel: TCHChannel) -> Channel? {
        let name = TwilioHelper.shared.getName(of: twilioChannel)

        return CoreDataHelper.shared.getChannel(withName: name)
    }

    func getChannel(withName username: String) -> Channel? {
        let channels = self.getChannels()

        return channels.first { $0.name == username }
    }

    func getChannels() -> [Channel] {
        return self.currentAccount?.channels ?? []
    }

    func getChannel(with identity: String) -> Channel? {
        return CoreDataHelper.shared.getSingleChannels().first { $0.name == identity }
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
