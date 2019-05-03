//
//  ChatsManager+Join.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 5/3/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import TwilioChatClient

extension ChatsManager {
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
}
