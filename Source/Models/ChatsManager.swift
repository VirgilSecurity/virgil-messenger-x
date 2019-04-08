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
    public static func addChat(with identity: String,
                               startProgressBar: @escaping () -> Void,
                               completion: @escaping (Error?) -> Void) {
        do {
            let identity = identity.lowercased()

            guard identity != TwilioHelper.shared.username else {
                throw UserFriendlyError.createSelfChatForbidded
            }

            let exists = CoreDataHelper.shared.getChannels().contains { $0.name == identity }

            guard !exists else {
                throw UserFriendlyError.douleChannelForbidded
            }

            startProgressBar()

            let getCardOperation = VirgilHelper.shared.getCard(identity: identity)
            let createTwilioChannelOperation = TwilioHelper.shared.makeCreateChannelOperation(with: identity)
            let createCoreDataChannelOperation = CoreDataHelper.shared.createChannel(identity: identity)
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

    static func makeUpdateChannelsOperation() -> CallbackOperation<Void> {
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

    // FIXME
    static func makeUpdateChannelOperation(twilioChannel: TCHChannel) -> CallbackOperation<Void> {
        return CallbackOperation<Void> { _, completion in
            do {
                if twilioChannel.status == TCHChannelStatus.invited {
                    try TwilioHelper.shared.makeJoinOperation(channel: twilioChannel).startSync().getResult()
                    let name = TwilioHelper.shared.getName(of: twilioChannel)
                    let card = try VirgilHelper.shared.getCard(identity: name).startSync().getResult()
                    try CoreDataHelper.shared.createChannel(name: name, cards: [card])
                }

                let name = TwilioHelper.shared.getName(of: twilioChannel)

                guard let coreChannel = CoreDataHelper.shared.getChannel(withName: name) else {
                    throw NSError()
                }

                guard let count = coreChannel.message?.count else {
                    throw NSError()
                }

                let coreCount = UInt(count)

                twilioChannel.getMessagesCount { result, twilioCount in
                    if let error = result.error {
                        completion(nil, error)
                        return
                    }

                    let toLoad = twilioCount - coreCount

                    guard toLoad > 0 else {
                        CoreDataHelper.shared.setLastMessage(for: coreChannel)
                        completion((), nil)
                        return
                    }

                    twilioChannel.messages?.getLastWithCount(toLoad) { result, messages in
                        if let error = result.error {
                            completion(nil, error)
                            return
                        }

                        // FIXME
                        for message in messages! {
                            _ = try! MessageProcessor.process(message: message, from: twilioChannel)
                            completion((), nil)
                        }
                    }
                }
            } catch {
                completion(nil, error)
            }
        }
    }
}
