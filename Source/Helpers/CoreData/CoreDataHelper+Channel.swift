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
    func makeCreateGroupChannelOperation(name: String, members: [String]) -> CallbackOperation<Void> {
        return CallbackOperation<Void> { operation, completion in
            do {
                let channels = members.map { CoreDataHelper.shared.getSingleChannel(with: $0)! }
                let cards = channels.map { $0.cards.first! }

                _ = try self.createChannel(type: .group, name: name, cards: cards)

                completion((), nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }

    func makeCreateSingleChannelOperation() -> CallbackOperation<Void> {
        return CallbackOperation { operation, completion in
            do {
                var cards: [Card] = try operation.findDependencyResult()

                cards = cards.filter { !self.existsSingleChannel(with: $0.identity) }

                try cards.forEach {
                    _ = try self.createChannel(type: .single, name: $0.identity, cards: [$0])
                }

                completion((), nil)
            } catch {
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

    func add(_ cards: [Card], to channel: Channel) {
        let members = channel.cards.map { $0.identity }
        var cardsToAdd: [Card] = []

        for card in cards {
            if !members.contains(card.identity) {
                cardsToAdd.append(card)
            }
        }

        channel.cards += cardsToAdd

        self.appDelegate.saveContext()
    }

    func remove(_ cards: [Card], from channel: Channel) {
        channel.cards = channel.cards.filter { card1 in
            !cards.contains { card2 in
                card1.identity == card2.identity
            }
        }

        self.appDelegate.saveContext()
    }

    func delete(channel: Channel) {
        channel.messages.forEach { self.managedContext.delete($0) }
        channel.serviceMessages.forEach { self.managedContext.delete($0) }

        self.managedContext.delete(channel)

        self.appDelegate.saveContext()
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

    func existsSingleChannel(with identity: String) -> Bool {
        return self.getSingleChannel(with: identity) != nil ? true : false
    }

    func existsChannel(name: String) -> Bool {
        return self.currentAccount?.channels.contains { $0.name == name } ?? false
    }

    func getChannel(_ twilioChannel: TCHChannel) -> Channel? {
        let name = TwilioHelper.shared.getName(of: twilioChannel)

        return CoreDataHelper.shared.getChannel(withName: name)
    }

    func getChannel(withName name: String) -> Channel? {
        let channels = self.getChannels()

        return channels.first { $0.name == name }
    }

    func getChannels() -> [Channel] {
        return self.currentAccount?.channels ?? []
    }

    func getSingleChannel(with identity: String) -> Channel? {
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
