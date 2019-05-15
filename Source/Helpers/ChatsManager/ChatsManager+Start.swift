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
    public static func startSingle(with identity: String,
                                   startProgressBar: (() -> Void),
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

            ChatsManager.makeStartSingleOperation(with: [identity]).start(completion: { completion($1) })
        } catch {
            completion(error)
        }
    }

    public static func makeStartSingleOperation(with identities: [String]) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            guard !identities.isEmpty else {
                completion((), nil)
                return
            }

            let getCardOperation = VirgilHelper.shared.makeGetCardsOperation(identities: identities)
            let createTwilioChannelOperation = TwilioHelper.shared.makeCreateSingleChannelOperation(with: identities)
            let createCoreDataChannelOperation = CoreDataHelper.shared.makeCreateSingleChannelOperation()
            let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

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
        }
    }
    
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

            let createTwilioChannelOperation = TwilioHelper.shared.makeCreateGroupChannelOperation(with: members,
                                                                                                   name: name)

            let createCoreDataChannelOperation = CoreDataHelper.shared.makeCreateGroupChannelOperation(name: name,
                                                                                                       members: members)

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
}
