//
//  CoreData+Channel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import CoreData
import VirgilSDK
import TwilioChatClient

extension CoreData {
    func createGroupChannel(name: String, members: [String], sid: String, sessionId: Data, additionalCards: [Card] = []) throws {
        let account = try self.getCurrentAccount()

        let members = members.filter { $0 != account.identity }

        var cards: [Card] = additionalCards
        for member in members {
            if let channel = CoreData.shared.getSingleChannel(with: member),
                !additionalCards.contains(where: { $0.identity ==  member }) {
                    cards.append(channel.cards.first!)
            }
        }

        _ = try self.createChannel(type: .group, sid: sid, name: name, cards: cards, sessionId: sessionId)
    }

    func createSingleChannel(sid: String, card: Card) throws {
        guard !self.existsSingleChannel(with: card.identity), card.identity != Twilio.shared.identity else {
            return
        }

        _ = try self.createChannel(type: .single, sid: sid, name: card.identity, cards: [card])
    }

    private func createChannel(type: ChannelType, sid: String, name: String, cards: [Card], sessionId: Data? = nil) throws -> Channel {
        let account = try self.getCurrentAccount()

        let channel = try Channel(sid: sid,
                                  name: name,
                                  type: type,
                                  account: account,
                                  cards: cards,
                                  sessionId: sessionId,
                                  managedContext: self.managedContext)

        try self.saveContext()

        return channel
    }

    func add(_ cards: [Card], to channel: Channel) throws {
        let members = channel.cards.map { $0.identity }
        var cardsToAdd: [Card] = []

        for card in cards {
            if !members.contains(card.identity), card.identity != Twilio.shared.identity {
                cardsToAdd.append(card)
            }
        }

        channel.cards += cardsToAdd

        try self.saveContext()
    }

    func remove(_ cards: [Card], from channel: Channel) throws {
        channel.cards = channel.cards.filter { card1 in
            !cards.contains { card2 in
                card1.identity == card2.identity
            }
        }

        try self.saveContext()
    }

    func delete(channel: Channel) throws {
        channel.allMessages.forEach { self.managedContext.delete($0) }
        channel.serviceMessages.forEach { self.managedContext.delete($0) }

        self.managedContext.delete(channel)

        try self.saveContext()
    }

    func existsSingleChannel(with identity: String) -> Bool {
        return self.getSingleChannels().contains { $0.name == identity }
    }

    func existsChannel(sid: String) -> Bool {
        return self.getChannels().contains { $0.sid == sid }
    }

    func getChannel(_ twilioChannel: TCHChannel) throws -> Channel {
        let twilioSid = try twilioChannel.getSid()
        
        guard let channel = self.getChannels().first(where: { $0.sid == twilioSid }) else {
            throw Error.channelNotFound
        }

        return channel
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

    func getCurrentChannel() throws -> Channel {
        guard let channel = self.currentChannel else {
            throw Error.nilCurrentChannel
        }

        return channel
    }
}