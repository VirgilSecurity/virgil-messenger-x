//
//  Twilio+Channel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 3/5/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import TwilioChatClient
import VirgilSDK

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
                    completion(nil, result.error)
                    return
                }

                completion(channel, nil)
            }
        }
    }

    func makeUniqueName(_ user1: String, _ user2: String) -> String {
        if user1 > user2 {
            return Virgil.shared.makeHash(from: user1 + user2)!
        } else {
            return Virgil.shared.makeHash(from: user2 + user1)!
        }
    }
}

extension Twilio {
    func createSingleChannel(with cards: [Card]) -> CallbackOperation<Void> {
        return CallbackOperation { operation, completion in
            if let error = operation.findDependencyError() {
                completion(nil, error)
                return
            }

            guard !cards.isEmpty else {
                completion((), nil)
                return
            }

            let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

            var operations: [CallbackOperation<Void>] = []

            cards.forEach {
                let operation = self.createSingleChannel(with: $0)
                completionOperation.addDependency(operation)
                operations.append(operation)
            }

            let queue = OperationQueue()
            queue.addOperations(operations + [completionOperation], waitUntilFinished: false)
        }
    }

    func createSingleChannel(with card: Card) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            self.queue.async {
                do {
                    let attributes = TCHChannel.Attributes(initiator: self.identity,
                                                           friendlyName: nil,
                                                           sessionId: nil,
                                                           members: [self.identity, card.identity],
                                                           type: .single)

                    let uniqueName = self.makeUniqueName(card.identity, self.identity)
                    let options: [String: Any] = [TCHChannelOptionType: TCHChannelType.private.rawValue,
                                                  TCHChannelOptionAttributes: try attributes.export(),
                                                  TCHChannelOptionUniqueName: uniqueName]

                    let channel = try self.makeCreateChannelOperation(with: options).startSync().getResult()

                    try channel.join().startSync().getResult()

                    try CoreData.shared.createSingleChannel(sid: channel.sid!, card: card)

                    try channel.invite(identity: card.identity).startSync().getResult()

                    completion((), nil)
                } catch {
                    completion(nil, error)
                }
            }
        }
    }

    func createGroupChannel(with members: [String], name: String, sessionId: Data) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            self.queue.async {
                do {
                    let attributes = TCHChannel.Attributes(initiator: self.identity,
                                                           friendlyName: name,
                                                           sessionId: sessionId,
                                                           members: [self.identity] + members,
                                                           type: .group)

                    let options: [String: Any] = [TCHChannelOptionType: TCHChannelType.private.rawValue,
                                                  TCHChannelOptionFriendlyName: name,
                                                  TCHChannelOptionAttributes: try attributes.export()]

                    let channel = try self.makeCreateChannelOperation(with: options).startSync().getResult()

                    try channel.join().startSync().getResult()

                    let sid = try channel.getSid()

                    try CoreData.shared.createGroupChannel(name: name, members: members, sid: sid, sessionId: sessionId)

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
    }

    func add(members: [String]) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let channel = try self.getCurrentChannel()

                var attributes = try channel.getAttributes()

                attributes.members += members

                let setAttributesOperation = channel.setAttributes(attributes)

                let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

                var operations: [CallbackOperation<Void>] = []

                completionOperation.addDependency(setAttributesOperation)
                operations.append(setAttributesOperation)

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
