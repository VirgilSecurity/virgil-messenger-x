//
//  TwilioHelper+Channel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 3/5/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import TwilioChatClient
import VirgilSDK

extension TwilioHelper {
    func getAttributes(of channel: TCHChannel) throws -> ChannelAttributes {
        guard let attributes = channel.attributes() else {
            throw TwilioHelperError.invalidChannel
        }

        return try ChannelAttributes.import(attributes)
    }

    func getCompanion(from attributes: ChannelAttributes) throws -> String {
        guard let companion = attributes.members.first(where: { $0 != self.identity }) else {
            throw TwilioHelperError.invalidChannel
        }

        return companion
    }

    func makeJoinOperation(channel: TCHChannel) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            channel.join { result in
                guard result.isSuccessful() else {
                    completion(nil, result.error)
                    return
                }

                completion((), nil)
            }
        }
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

    private func makeInviteOperation(identity: String, channel: TCHChannel) -> CallbackOperation<Void> {
        return CallbackOperation { operation, completion in
            channel.members!.invite(byIdentity: identity) { result in
                guard result.isSuccessful() else {
                    completion(nil, result.error)
                    return
                }

                completion((), nil)
            }
        }
    }

    func setAttributes(_ attributes: ChannelAttributes, to channel: TCHChannel) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let newAttributes = try attributes.export()

                channel.setAttributes(newAttributes) { result in
                    if let error = result.error {
                        completion(nil, error)
                    } else {
                        completion((), nil)
                    }
                }
            } catch {
                completion(nil, error)
            }
        }
    }

    func getMessagesCount(in channel: TCHChannel) -> CallbackOperation<Int> {
        return CallbackOperation { _, completion in
            channel.getMessagesCount { result, count in
                if let error = result.error {
                    completion(nil, error)
                } else {
                    completion(Int(count), nil)
                }
            }
        }
    }

    func getLastMessages(withCount count: UInt, from messages: TCHMessages?) -> CallbackOperation<[TCHMessage]> {
        return CallbackOperation { _, completion in
            guard let messages = messages else {
                completion([], nil)
                return
            }

            messages.getLastWithCount(count) { result, messages in
                if let error = result.error {
                    completion(nil, error)
                } else {
                    completion(messages ?? [], nil)
                }
            }
        }
    }

    func makeUniqueName(_ user1: String, _ user2: String) -> String {
        if user1 > user2 {
            return VirgilHelper.shared.makeHash(from: user1 + user2)!
        } else {
            return VirgilHelper.shared.makeHash(from: user2 + user1)!
        }
    }
}

extension TwilioHelper {
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
                    let attributes = ChannelAttributes(initiator: self.identity,
                                                       friendlyName: nil,
                                                       sessionId: nil,
                                                       members: [self.identity, card.identity],
                                                       type: .single)

                    let uniqueName = self.makeUniqueName(card.identity, self.identity)
                    let options: [String: Any] = [TCHChannelOptionType: TCHChannelType.private.rawValue,
                                                  TCHChannelOptionAttributes: try attributes.export(),
                                                  TCHChannelOptionUniqueName: uniqueName]

                    let channel = try self.makeCreateChannelOperation(with: options).startSync().getResult()

                    try self.makeJoinOperation(channel: channel).startSync().getResult()

                    try CoreDataHelper.shared.createSingleChannel(sid: channel.sid!, card: card)

                    try self.makeInviteOperation(identity: card.identity, channel: channel).startSync().getResult()

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
                    let attributes = ChannelAttributes(initiator: self.identity,
                                                       friendlyName: name,
                                                       sessionId: sessionId,
                                                       members: [self.identity] + members,
                                                       type: .group)

                    let options: [String: Any] = [TCHChannelOptionType: TCHChannelType.private.rawValue,
                                                  TCHChannelOptionFriendlyName: name,
                                                  TCHChannelOptionAttributes: try attributes.export()]

                    let channel = try self.makeCreateChannelOperation(with: options).startSync().getResult()

                    try self.makeJoinOperation(channel: channel).startSync().getResult()

                    try CoreDataHelper.shared.createGroupChannel(name: name, members: members, sid: channel.sid!, sessionId: sessionId)

                    let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

                    var operations: [CallbackOperation<Void>] = []

                    members.forEach {
                        let inviteOperation = self.makeInviteOperation(identity: $0, channel: channel)
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
                guard let channel = TwilioHelper.shared.currentChannel else {
                    throw TwilioHelperError.nilCurrentChannel
                }

                var attributes = try self.getAttributes(of: channel)

                attributes.members += members

                let setAttributesOperation = self.setAttributes(attributes, to: channel)

                let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

                var operations: [CallbackOperation<Void>] = []

                completionOperation.addDependency(setAttributesOperation)
                operations.append(setAttributesOperation)

                members.forEach {
                    let operation = self.makeInviteOperation(identity: $0, channel: channel)
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
                guard let channel = self.currentChannel else {
                    throw TwilioHelperError.nilCurrentChannel
                }

                var attributes = try self.getAttributes(of: channel)

                attributes.members = attributes.members.filter { $0 != member }

                let setAttributesOperation = self.setAttributes(attributes, to: channel)

                let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

                completionOperation.addDependency(setAttributesOperation)

                let operations = [setAttributesOperation, completionOperation]

                let queue = OperationQueue()
                queue.addOperations(operations, waitUntilFinished: false)
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

                    if let channel = CoreDataHelper.shared.getChannel(channel) {
                        try CoreDataHelper.shared.delete(channel: channel)
                    }

                    completion((), nil)
                } catch {
                    completion(nil, error)
                }
            }
        }
    }
}
