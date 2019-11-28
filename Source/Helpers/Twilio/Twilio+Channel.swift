//
//  Twilio+Channel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 3/5/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import TwilioChatClient
import VirgilSDK
import VirgilE3Kit

extension Twilio {
    public func getCurrentChannel() throws -> TCHChannel {
        guard let channel = self.currentChannel else {
            throw Error.nilCurrentChannel
        }

        return channel
    }

    func getCompanion(from attributes: TCHChannel.Attributes) throws -> String {
        guard let companion = attributes.members.first(where: { $0 != self.identity }) else {
            throw Error.invalidChannel
        }

        return companion
    }

    private func makeCreateChannelOperation(with options: [String: Any]) -> CallbackOperation<TCHChannel> {
        return CallbackOperation { _, completion in
            self.channels.createChannel(options: options) { result, channel in
                guard result.isSuccessful() else {
                    return completion(nil, result.error)
                }

                completion(channel, nil)
            }
        }
    }

    func makeUniqueName(_ user1: String, _ user2: String) -> String {
        if user1 > user2 {
            return Virgil.shared.makeHash(from: user1 + user2)
        } else {
            return Virgil.shared.makeHash(from: user2 + user1)
        }
    }
}

extension Twilio {
//    func createSingleChannel(with cards: [Card]) throws {
//        try cards.forEach {
//            try self.createSingleChannel(with: $0).startSync().get()
//        }
//    }

    func createSingleChannel(with card: Card) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let uniqueName = self.makeUniqueName(card.identity, self.identity)

                let options = try TCHChannel.Options(uniqueName: uniqueName,
                                                     friendlyName: nil,
                                                     initiator: self.identity,
                                                     members: [self.identity, card.identity],
                                                     type: .single).export()

                let channel = try self.makeCreateChannelOperation(with: options).startSync().get()

                let sid = try channel.getSid()

                _ = try CoreData.shared.createSingleChannel(sid: sid, card: card)

                try channel.invite(identity: card.identity).startSync().get()

                completion((), nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    func createGroupChannel(with cards: [Card], group: Group, name: String, id: Data) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let members = cards.map { $0.identity }

                let options = try TCHChannel.Options(uniqueName: id.hexEncodedString(),
                                                     friendlyName: name,
                                                     initiator: self.identity,
                                                     members: [self.identity] + members,
                                                     type: .group).export()

                let channel = try self.makeCreateChannelOperation(with: options).startSync().get()

                let sid = try channel.getSid()

                let coreChannel = try CoreData.shared.createGroupChannel(name: name, members: members, sid: sid, sessionId: id, cards: cards)
                coreChannel.set(group: group)

                let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

                var operations: [CallbackOperation<Void>] = []

                members.forEach {
                    let inviteOperation = channel.invite(identity: $0)
                    completionOperation.addDependency(inviteOperation)
                    operations.append(inviteOperation)
                }

                let queue = OperationQueue()
                queue.addOperations(operations + [completionOperation], waitUntilFinished: false)
            } catch {
                completion(nil, error)
            }
        }
    }

    func add(members: [String]) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let channel = try self.getCurrentChannel()

                var attributes = try channel.getAttributes()

                attributes.initiator = self.identity
                attributes.members += members

                try channel.setAttributes(attributes).startSync().get()

                let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

                var operations: [CallbackOperation<Void>] = []

                members.forEach {
                    let operation = channel.invite(identity: $0)
                    completionOperation.addDependency(operation)
                    operations.append(operation)
                }

                let queue = OperationQueue()
                queue.addOperations(operations + [completionOperation], waitUntilFinished: false)
            } catch {
                completion(nil, error)
            }
        }
    }

    func remove(member: String) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let channel = try self.getCurrentChannel()

                var attributes = try channel.getAttributes()

                attributes.initiator = self.identity
                attributes.members = attributes.members.filter { $0 != member }

                channel.setAttributes(attributes).start(completion: completion)
            } catch {
                completion(nil, error)
            }
        }
    }

    func leave(_ channel: TCHChannel) -> CallbackOperation<Void> {
        return CallbackOperation { operation, completion in
            channel.leave { result in
                do {
                    if let error = result.error {
                        throw error
                    }

                    let channel = try CoreData.shared.getChannel(channel)

                    try CoreData.shared.delete(channel: channel)

                    completion((), nil)
                } catch {
                    completion(nil, error)
                }
            }
        }
    }
}
