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
    func createGroupChannel(name: String, members: [String], sid: String) throws {
        let members = members.filter { $0 != self.currentAccount?.identity }
        let channels = members.map { CoreDataHelper.shared.getSingleChannel(with: $0)! }
        let cards = channels.map { $0.cards.first! }

        _ = try self.createChannel(type: .group, sid: sid, name: name, cards: cards)
    }

    func createSingleChannel(sid: String, card: Card) throws {
        guard !self.existsSingleChannel(with: card.identity), card.identity != TwilioHelper.shared.username else {
            return
        }

        _ = try self.createChannel(type: .single, sid: sid, name: card.identity, cards: [card])
    }

    private func createChannel(type: ChannelType, sid: String, name: String, cards: [Card]) throws -> Channel {
        guard let account = self.currentAccount else {
            throw CoreDataHelperError.nilCurrentAccount
        }

        let channel = try Channel(sid: sid,
                                  name: name,
                                  type: type,
                                  account: account,
                                  cards: cards,
                                  sessionId: nil,
                                  managedContext: self.managedContext)

        try self.appDelegate.saveContext()

        return channel
    }

    func add(_ cards: [Card], to channel: Channel) throws {
        let members = channel.cards.map { $0.identity }
        var cardsToAdd: [Card] = []

        for card in cards {
            if !members.contains(card.identity), card.identity != TwilioHelper.shared.username {
                cardsToAdd.append(card)
            }
        }

        channel.cards += cardsToAdd

        try self.appDelegate.saveContext()
    }

    func remove(_ cards: [Card], from channel: Channel) throws {
        channel.cards = channel.cards.filter { card1 in
            !cards.contains { card2 in
                card1.identity == card2.identity
            }
        }

        try self.appDelegate.saveContext()
    }

    func delete(channel: Channel) throws {
        channel.messages.forEach { self.managedContext.delete($0) }
        channel.serviceMessages.forEach { self.managedContext.delete($0) }

        self.managedContext.delete(channel)

        try self.appDelegate.saveContext()
    }

    func set(sessionId: Data, for channel: Channel) throws {
        guard channel.sessionId != sessionId else {
            return
        }
        
        channel.sessionId = sessionId

        try self.appDelegate.saveContext()
    }

    func existsSingleChannel(with identity: String) -> Bool {
        return self.getSingleChannels().contains { $0.name == identity }
    }

    func existsChannel(sid: String) -> Bool {
        return self.getChannels().contains { $0.sid == sid }
    }

    func getChannel(_ twilioChannel: TCHChannel) -> Channel? {
        return self.getChannels().first { $0.sid == twilioChannel.sid! }
    }

    func getChannel(withName name: String) -> Channel? {
        return self.getChannels().first { $0.name == name }
    }

    func getChannels() -> [Channel] {
        return self.currentAccount!.channels
    }

    func getSingleChannel(with identity: String) -> Channel? {
        return self.getSingleChannels().first { $0.name == identity }
    }

    func getSingleChannels() -> [Channel] {
        return self.getChannels().filter { $0.type == .single }
    }
}
