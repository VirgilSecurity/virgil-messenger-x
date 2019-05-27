//
//  TwilioHelper+Channel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 3/5/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import TwilioChatClient
import VirgilSDK

extension TwilioHelper {
    func getAttributes(of channel: TCHChannel) throws -> ChannelAttributes {
        guard let attributes = channel.attributes() else {
            throw TwilioHelperError.missingChannelAttributes
        }

        return try ChannelAttributes.import(attributes)
    }

    func getCompanion(from attributes: ChannelAttributes) -> String {
        return attributes.members.first { $0 != self.username }!
    }

    func makeJoinOperation(channel: TCHChannel) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            channel.join { result in
                guard result.isSuccessful() else {
                    completion(nil, TwilioHelperError.joiningFailed)
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

    private func makeRemoveOperation(identity: String, channel: TCHChannel) -> CallbackOperation<Void> {
        return CallbackOperation { operation, completion in
            // FIXME: add pages of members
            channel.members!.members { result, paginator in
                guard let paginator = paginator, result.isSuccessful() else {
                    completion(nil, result.error)
                    return
                }

                let members = paginator.items()

                let candidate = members.first { $0.identity == identity }

                guard let member = candidate else {
                    completion(nil, NSError())
                    return
                }

                channel.members!.remove(member) { result in
                    guard result.isSuccessful() else {
                        completion(nil, result.error)
                        return
                    }

                    completion((), nil)
                }
            }
        }
    }

    func leave(_ channel: TCHChannel) -> CallbackOperation<Void> {
        return CallbackOperation { operation, completion in
            channel.leave { result in
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

    func add(members: [String], to channel: TCHChannel) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
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

    func remove(member: String, from channel: TCHChannel) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
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

    func makeCreateSingleChannelOperation(with card: Card) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let attributes = ChannelAttributes(initiator: self.username,
                                                   friendlyName: nil,
                                                   members: [self.username, card.identity],
                                                   type: .single)

                let uniqueName = self.makeUniqueName(card.identity, self.username)
                let options: [String: Any] = [TCHChannelOptionType: TCHChannelType.private.rawValue,
                                              TCHChannelOptionAttributes: try attributes.export(),
                                              TCHChannelOptionUniqueName: uniqueName]

                // FIXME join operation
                let channel = try self.makeCreateChannelOperation(with: options).startSync().getResult()

                try CoreDataHelper.shared.createSingleChannel(sid: channel.sid!, card: card)

                try self.makeInviteOperation(identity: card.identity, channel: channel).startSync().getResult()

                completion((), nil)
            } catch {
                completion(nil, error)
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

    func makeCreateSingleChannelOperation(with cards: [Card]) -> CallbackOperation<Void> {
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
                let operation = self.makeCreateSingleChannelOperation(with: $0)
                completionOperation.addDependency(operation)
                operations.append(operation)
            }

            let queue = OperationQueue()
            queue.addOperations(operations + [completionOperation], waitUntilFinished: false)
        }
    }

    func makeCreateGroupChannelOperation(with members: [String], name: String) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let attributes = ChannelAttributes(initiator: self.username,
                                                   friendlyName: name,
                                                   members: [self.username] + members,
                                                   type: .group)

                let options: [String: Any] = [TCHChannelOptionType: TCHChannelType.private.rawValue,
                                              TCHChannelOptionFriendlyName: name,
                                              TCHChannelOptionAttributes: try attributes.export()]

                let channel = try self.makeCreateChannelOperation(with: options).startSync().getResult()
                
                try CoreDataHelper.shared.createGroupChannel(name: name, members: members, sid: channel.sid!)

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
