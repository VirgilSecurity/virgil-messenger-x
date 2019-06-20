//
//  ChatsManager+Update.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 5/3/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import TwilioChatClient

extension ChatsManager {
    private static let queue = DispatchQueue(label: "ChatsManager")

    public static func makeUpdateChannelsOperation() -> CallbackOperation<Void> {
        return CallbackOperation { operation, completion in
            self.queue.async {
                do {
                    if let error = operation.findDependencyError() {
                        throw error
                    }

                    let twilioChannels = TwilioHelper.shared.channels.subscribedChannels()

                    guard twilioChannels.count > 0 else {
                        completion((), nil)
                        return
                    }

                    var singleChannelOperations: [CallbackOperation<Void>] = []
                    var groupChannelOperations: [CallbackOperation<Void>] = []

                    for twilioChannel in twilioChannels {
                        let operation = self.makeUpdateChannelOperation(twilioChannel: twilioChannel)

                        let attributes = try twilioChannel.getAttributes()

                        switch attributes.type {
                        case .single:
                            singleChannelOperations.append(operation)
                        case .group:
                            groupChannelOperations.append(operation)
                        }
                    }

                    for singleOperation in singleChannelOperations {
                        for groupOperation in groupChannelOperations {
                            groupOperation.addDependency(singleOperation)
                        }
                    }

                    let operations = singleChannelOperations + groupChannelOperations

                    let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

                    operations.forEach {
                        completionOperation.addDependency($0)
                    }

                    let queue = OperationQueue()
                    queue.addOperations(operations + [completionOperation], waitUntilFinished: false)
                } catch {
                    completion(nil, error)
                }
            }
        }
    }

    public static func makeUpdateChannelOperation(twilioChannel: TCHChannel) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let coreChannel: Channel
                if let channel = try? CoreDataHelper.shared.getChannel(twilioChannel) {
                    coreChannel = channel
                } else {
                    try twilioChannel.join().startSync().getResult()

                    try ChatsManager.join(twilioChannel)

                    coreChannel = try CoreDataHelper.shared.getChannel(twilioChannel)
                }

                let coreCount = coreChannel.messagesCount
                let twilioCount = try twilioChannel.getMessagesCount().startSync().getResult()

                let toLoad = twilioCount - coreCount

                guard toLoad > 0 else {
                    completion((), nil)
                    return
                }

                let messages = try twilioChannel.getLastMessages(withCount: toLoad).startSync().getResult()

                for message in messages {
                    if !CoreDataHelper.shared.existsChannel(sid: twilioChannel.sid!) {
                        break
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
