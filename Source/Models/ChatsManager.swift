//
//  ChatManager.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/26/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import TwilioChatClient

public enum ChatsManager {
    public static func startGroup(with channels: [Channel],
                                  name: String,
                                  startProgressBar: @escaping () -> Void,
                                  completion: @escaping (Error?) -> Void) {
        do {
            let name = name.lowercased()

            let exists = CoreDataHelper.shared.getChannels().contains { $0.name == name }

            guard !exists else {
                throw UserFriendlyError.doubleChannelForbidded
            }

            guard !channels.isEmpty else {
                throw UserFriendlyError.unknownError
            }

            startProgressBar()

            // FIXME
            let members = channels.map { $0.name }
            let cards = channels.map { $0.cards.first! }

            let createTwilioChannelOperation = TwilioHelper.shared.makeCreateGroupChannelOperation(with: members, name: name)
            let createCoreDataChannelOperation = CoreDataHelper.shared.makeCreateGroupChannelOperation(name: name,
                                                                                                       members: members,
                                                                                                       cards: cards)

            let operations = [createTwilioChannelOperation, createCoreDataChannelOperation]

            let completionOperation = OperationUtils.makeCompletionOperation { (_: Void?, error: Error?) in completion(error) }

            operations.forEach {
                completionOperation.addDependency($0)
            }

            let queue = OperationQueue()
            queue.addOperations(operations + [completionOperation], waitUntilFinished: false)
        } catch {
            completion(error)
        }
    }

    public static func joinGroup(with members: [String],
                                 name: String) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            let getCardsOperation = VirgilHelper.shared.makeGetCardsOperation(identities: members)
            let createCoreDataGroupOperation = CoreDataHelper.shared.makeCreateGroupChannelOperation(name: name, members: members)
            let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

            let operations = [getCardsOperation, createCoreDataGroupOperation, completionOperation]

            createCoreDataGroupOperation.addDependency(getCardsOperation)
            completionOperation.addDependency(getCardsOperation)
            completionOperation.addDependency(createCoreDataGroupOperation)

            let queue = OperationQueue()
            queue.addOperations(operations, waitUntilFinished: false)
        }
    }

    public static func startSingle(with identity: String,
                                   startProgressBar: @escaping () -> Void,
                                   completion: @escaping (Error?) -> Void) {
        do {
            let identity = identity.lowercased()

            guard identity != TwilioHelper.shared.username else {
                throw UserFriendlyError.createSelfChatForbidded
            }

            let exists = CoreDataHelper.shared.getChannels().contains { $0.name == identity }

            guard !exists else {
                throw UserFriendlyError.doubleChannelForbidded
            }

            startProgressBar()

            let getCardOperation = VirgilHelper.shared.makeGetCardsOperation(identities: [identity])
            let createTwilioChannelOperation = TwilioHelper.shared.makeCreateSingleChannelOperation(with: identity)
            let createCoreDataChannelOperation = CoreDataHelper.shared.makeCreateSingleChannelOperation(with: identity)
            let completionOperation = OperationUtils.makeCompletionOperation { (_: Void?, error: Error?) in completion(error) }

            createCoreDataChannelOperation.addDependency(getCardOperation)
            createTwilioChannelOperation.addDependency(getCardOperation)

            let operations = [getCardOperation,
                              createTwilioChannelOperation,
                              createCoreDataChannelOperation]

            operations.forEach {
                completionOperation.addDependency($0)
            }

            let queue = OperationQueue()
            queue.addOperations(operations + [completionOperation], waitUntilFinished: false)
        } catch {
            completion(error)
        }
    }

    public static func joinSingle(with identity: String) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let cards = try VirgilHelper.shared.makeGetCardsOperation(identities: [identity]).startSync().getResult()

                try CoreDataHelper.shared.createChannel(type: .single, name: identity, cards: cards)

                completion((), nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    public static func makeUpdateChannelsOperation() -> CallbackOperation<Void> {
        return CallbackOperation<Void> { _, completion in
            let twilioChannels = TwilioHelper.shared.channels.subscribedChannels()

            guard twilioChannels.count > 0 else {
                completion((), nil)
                return
            }

            var operations: [CallbackOperation<Void>] = []

            for twilioChannel in twilioChannels {
                let operation = self.makeUpdateChannelOperation(twilioChannel: twilioChannel)
                operations.append(operation)
            }

            let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

            operations.forEach {
                completionOperation.addDependency($0)
            }

            let queue = OperationQueue()
            queue.addOperations(operations + [completionOperation], waitUntilFinished: false)
        }
    }

    public static func join(_ channel: TCHChannel) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let attributes = try TwilioHelper.shared.getAttributes(of: channel)
                let name = TwilioHelper.shared.getName(of: channel)

                let joinOperation: CallbackOperation<Void>
                switch attributes.type {
                case .single:
                    joinOperation = self.joinSingle(with: name)
                case .group:
                    let members = attributes.members.filter { $0 != TwilioHelper.shared.username }

                    joinOperation = self.joinGroup(with: members, name: name)
                }

                let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

                completionOperation.addDependency(joinOperation)

                let queue = OperationQueue()
                queue.addOperations([joinOperation, completionOperation], waitUntilFinished: false)
            } catch {
                completion(nil, error)
            }
        }
    }

    // FIXME
    private static func makeUpdateChannelOperation(twilioChannel: TCHChannel) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                if twilioChannel.status == TCHChannelStatus.invited {
                    try TwilioHelper.shared.makeJoinOperation(channel: twilioChannel).startSync().getResult()
                    try self.join(twilioChannel).startSync().getResult()
                }

                let name = TwilioHelper.shared.getName(of: twilioChannel)

                guard let coreChannel = CoreDataHelper.shared.getChannel(withName: name) else {
                    throw NSError()
                }

                let count = coreChannel.messages.count

                let coreCount = UInt(count)

                twilioChannel.getMessagesCount { result, twilioCount in
                    if let error = result.error {
                        completion(nil, error)
                        return
                    }

                    let toLoad = twilioCount - coreCount

                    guard toLoad > 0 else {
                        completion((), nil)
                        return
                    }

                    twilioChannel.messages?.getLastWithCount(toLoad) { result, messages in
                        guard let messages = messages, result.isSuccessful() else {
                            completion(nil, result.error)
                            return
                        }

                        do {
                            for message in messages {
                                _ = try MessageProcessor.process(message: message, from: twilioChannel)
                            }

                            completion((), nil)
                        } catch {
                            completion(nil, error)
                        }

                    }
                }
            } catch {
                completion(nil, error)
            }
        }
    }
}
