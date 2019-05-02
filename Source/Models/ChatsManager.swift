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

            let members = channels.map { $0.name }
            let cards = channels.map { $0.cards.first! }

            let createTwilioChannelOperation = TwilioHelper.shared.makeCreateGroupChannelOperation(with: members,
                                                                                                   name: name)

            let createCoreDataChannelOperation = CoreDataHelper.shared.makeCreateGroupChannelOperation(name: name,
                                                                                                       members: members,
                                                                                                       cards: cards)

            createCoreDataChannelOperation.addDependency(createTwilioChannelOperation)

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
            let getCardsOperation = VirgilHelper.shared.makeGetCardsOperation(identities: [identity])
            let createCoreDataChannelOperation = CoreDataHelper.shared.makeCreateSingleChannelOperation(with: identity)
            let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

            let operations = [getCardsOperation, createCoreDataChannelOperation, completionOperation]

            createCoreDataChannelOperation.addDependency(getCardsOperation)
            completionOperation.addDependency(getCardsOperation)
            completionOperation.addDependency(createCoreDataChannelOperation)

            let queue = OperationQueue()
            queue.addOperations(operations, waitUntilFinished: false)
        }
    }
}

// Update Chats operations
extension ChatsManager {
    private static let queue = DispatchQueue(label: "test")

    public static func makeUpdateChannelsOperation() -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            self.queue.async {
                let twilioChannels = TwilioHelper.shared.channels.subscribedChannels()

                guard twilioChannels.count > 0 else {
                    completion((), nil)
                    return
                }

                var singleChannelOperations: [CallbackOperation<Void>] = []
                var groupChannelOperations: [CallbackOperation<Void>] = []

                for twilioChannel in twilioChannels {
                    let operation = self.makeUpdateChannelOperation(twilioChannel: twilioChannel)

                    let attributes = try! TwilioHelper.shared.getAttributes(of: twilioChannel)

                    switch attributes.type {
                    case .single:
                        singleChannelOperations.append(operation)
                    case .group:
                        groupChannelOperations.append(operation)
                    }
                }

//                groupChannelOperations.first!.addDependency(singleChannelOperations.first!)

                let operations = singleChannelOperations + groupChannelOperations

                let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

                operations.forEach {
                    completionOperation.addDependency($0)
                }

                let queue = OperationQueue()
                queue.addOperations(operations + [completionOperation], waitUntilFinished: false)
            }
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

    private static func makeUpdateChannelOperation(twilioChannel: TCHChannel) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                if twilioChannel.status == TCHChannelStatus.invited {
                    try TwilioHelper.shared.makeJoinOperation(channel: twilioChannel).startSync().getResult()
                    try ChatsManager.join(twilioChannel).startSync().getResult()
                }

                guard let coreChannel = CoreDataHelper.shared.getChannel(twilioChannel) else {
                    throw NSError()
                }

                let coreCount = UInt(coreChannel.messages.count)
                let twilioCount = try TwilioHelper.shared.getMessagesCount(in: twilioChannel).startSync().getResult()

                let toLoad = twilioCount - coreCount

                guard toLoad > 0 else {
                    completion((), nil)
                    return
                }

                let messages = try TwilioHelper.shared.getLastMessages(withCount: toLoad, from: twilioChannel.messages).startSync().getResult()

                for message in messages {
                    if message.author == TwilioHelper.shared.username {
                        continue
                    }

                    _ = try MessageProcessor.process(message: message, from: twilioChannel)
                }

                completion((), nil)
            } catch {
                completion(nil, error)
            }
        }
    }
}
