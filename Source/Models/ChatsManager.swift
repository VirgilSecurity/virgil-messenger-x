//
//  ChatManager.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/26/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import Foundation
import VirgilSDK

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
            let createTwilioChannelOperation = TwilioHelper.shared.createSingleChannel(with: identity)
            let createCoreDataChannelOperation = CoreDataHelper.shared.createChannel(identity: identity)
            let completionOperation = OperationUtils.makeCompletionOperation { (_: Void?, error: Error?) in completion(error) }

            createCoreDataChannelOperation.addDependency(getCardOperation)
            completionOperation.addDependency(getCardOperation)
            completionOperation.addDependency(createTwilioChannelOperation)
            completionOperation.addDependency(createCoreDataChannelOperation)

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
}
