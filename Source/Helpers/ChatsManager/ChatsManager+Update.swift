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
