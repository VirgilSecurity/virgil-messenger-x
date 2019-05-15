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

    func getName(of channel: TCHChannel) -> String {
        // FIXME
        guard let attributes = try? self.getAttributes(of: channel) else {
            return "Error name"
        }

        switch attributes.type {
        case .single:
            return self.getCompanion(of: channel)
        case .group:
            return channel.friendlyName ?? "Error name"
        }
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

    private func makeInviteOperation(identity: String, channel: TCHChannel? = nil) -> CallbackOperation<Void> {
        return CallbackOperation { operation, completion in
            do {
                let channel: TCHChannel = try channel ?? operation.findDependencyResult()

                channel.members?.invite(byIdentity: identity) { result in
                    guard result.isSuccessful() else {
                        completion(nil, result.error)
                        return
                    }

                    completion((), nil)
                }
            } catch {
                completion(nil, error)
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

    func getMessagesCount(in channel: TCHChannel) -> CallbackOperation<UInt> {
        return CallbackOperation { _, completion in
            channel.getMessagesCount { result, count in
                if let error = result.error {
                    completion(nil, error)
                } else {
                    completion(count, nil)
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

    func addMembers(_ identities: [String], to channel: TCHChannel) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                guard let rawAttributes = channel.attributes() else {
                    throw NSError()
                }

                var attributes = try ChannelAttributes.import(rawAttributes)
                attributes.members += identities

                let setAttributesOperation = self.setAttributes(attributes, to: channel)

                let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

                var operations: [CallbackOperation<Void>] = []

                completionOperation.addDependency(setAttributesOperation)
                operations.append(setAttributesOperation)

                identities.forEach {
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

    func makeCreateSingleChannelOperation(with identity: String) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            let attributes = ChannelAttributes(initiator: self.username,
                                               friendlyName: nil,
                                               members: [self.username, identity],
                                               type: .single)

            let options: [String: Any] = [TCHChannelOptionType: TCHChannelType.private.rawValue,
                                          TCHChannelOptionAttributes: try! attributes.export()]

            // FIXME join operation
            let createChannelOperation = self.makeCreateChannelOperation(with: options)
            let inviteOperation = self.makeInviteOperation(identity: identity)
            let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

            inviteOperation.addDependency(createChannelOperation)
            completionOperation.addDependency(createChannelOperation)
            completionOperation.addDependency(inviteOperation)

            let operations = [createChannelOperation, inviteOperation, completionOperation]

            let queue = OperationQueue()
            queue.addOperations(operations, waitUntilFinished: false)
        }
    }

    func makeCreateSingleChannelOperation(with identities: [String]) -> CallbackOperation<Void> {
        return CallbackOperation { operation, completion in
            if let error = operation.findDependencyError() {
                completion(nil, error)
                return
            }

            guard !identities.isEmpty else {
                completion((), nil)
                return
            }

            let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

            var operations: [CallbackOperation<Void>] = []

            identities.forEach {
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
            let attributes = ChannelAttributes(initiator: self.username,
                                               friendlyName: name,
                                               members: [self.username] + members,
                                               type: .group)

            let options: [String: Any] = [TCHChannelOptionType: TCHChannelType.private.rawValue,
                                          TCHChannelOptionFriendlyName: name,
                                          TCHChannelOptionAttributes: try! attributes.export()]

            let createChannelOperation = self.makeCreateChannelOperation(with: options)

            var inviteOperations: [CallbackOperation<Void>] = []

            members.forEach {
                let inviteOperation = self.makeInviteOperation(identity: $0)
                inviteOperation.addDependency(createChannelOperation)
                inviteOperations.append(inviteOperation)
            }

            let operations = [createChannelOperation] + inviteOperations

            let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

            operations.forEach {
                completionOperation.addDependency($0)
            }

            let queue = OperationQueue()
            queue.addOperations(operations + [completionOperation], waitUntilFinished: false)
        }
    }
}
