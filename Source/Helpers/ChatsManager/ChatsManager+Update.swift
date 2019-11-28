//
//  ChatsManager+Update.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 5/3/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import TwilioChatClient
import VirgilE3Kit

extension ChatsManager {
    private static let queue = DispatchQueue(label: "ChatsManager")

    public static func updateChannels() -> CallbackOperation<Void> {
        return CallbackOperation { operation, completion in
            self.queue.async {
                do {
                    if let error = operation.findDependencyError() {
                        throw error
                    }

                    let twilioChannels = Twilio.shared.channels.subscribedChannels()

                    guard twilioChannels.count > 0 else {
                        completion((), nil)
                        return
                    }

                    var singleChannelOperations: [CallbackOperation<Void>] = []
                    var groupChannelOperations: [CallbackOperation<Void>] = []

                    for twilioChannel in twilioChannels {
                        let operation = self.update(twilioChannel: twilioChannel)

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

    public static func update(twilioChannel: TCHChannel) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let coreChannel: Channel
                if let channel = try? CoreData.shared.getChannel(twilioChannel) {
                    coreChannel = channel

                    if coreChannel.type == .group {
                        let id = try twilioChannel.getSessionId()

                        guard let group = try Virgil.ethree.getGroup(id: id) else {
                            throw NSError()
                        }

                        try group.update().startSync().get()
                        coreChannel.set(group: group)
                    }
                }
                else {
                    try twilioChannel.join().startSync().get()

                    coreChannel = try ChatsManager.join(twilioChannel)
                }

                let coreCount = coreChannel.allMessages.count
                let twilioCount = try twilioChannel.getMessagesCount().startSync().get()

                let toLoad = twilioCount - coreCount

                guard toLoad > 0 else {
                    completion((), nil)
                    return
                }

                let messages = try twilioChannel.getLastMessages(withCount: toLoad).startSync().get()

                for message in messages {
                    let sid = try twilioChannel.getSid()
                    if !CoreData.shared.existsChannel(sid: sid) {
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
