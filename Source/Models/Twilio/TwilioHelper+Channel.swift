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

    private func makeInviteOperation(identity: String) -> CallbackOperation<Void> {
        return CallbackOperation { operation, completion in
            do {
                let channel: TCHChannel = try operation.findDependencyResult()

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

    func makeCreateSingleChannelOperation(with identity: String) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            let attributes = ChannelAttributes(initiator: self.username, members: [self.username, identity], type: .single)

            let options: [String: Any] = [TCHChannelOptionType: TCHChannelType.private.rawValue,
                                          TCHChannelOptionAttributes: try! attributes.export()]

            // FIXME join operation
            let createChannelOperation = self.makeCreateChannelOperation(with: options)
            let inviteOperation = self.makeInviteOperation(identity: identity)
            let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

            inviteOperation.addDependency(createChannelOperation)

            let operations = [createChannelOperation,
                              inviteOperation]

            operations.forEach {
                completionOperation.addDependency($0)
            }

            let queue = OperationQueue()
            queue.addOperations(operations + [completionOperation], waitUntilFinished: false)
        }
    }

    func makeCreateGroupChannelOperation(with members: [String], name: String) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            let attributes = ChannelAttributes(initiator: self.username,
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
