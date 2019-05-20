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
            }
        }
    }

    private static func makeUpdateChannelOperation(twilioChannel: TCHChannel) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let coreChannel: Channel
                if let channel = CoreDataHelper.shared.getChannel(twilioChannel) {
                    coreChannel = channel
                } else {
                    if twilioChannel.status != .joined {
                        try TwilioHelper.shared.makeJoinOperation(channel: twilioChannel).startSync().getResult()
                    }

                    try ChatsManager.join(twilioChannel).startSync().getResult()

                    guard let channel = CoreDataHelper.shared.getChannel(twilioChannel) else {
                        throw NSError()
                    }

                    coreChannel = channel
                }

                let coreCount = coreChannel.messages.count
                let twilioCount = try TwilioHelper.shared.getMessagesCount(in: twilioChannel).startSync().getResult()

                let toLoad = twilioCount - coreCount

                guard toLoad > 0 else {
                    completion((), nil)
                    return
                }

                let messages = try TwilioHelper.shared.getLastMessages(withCount: UInt(toLoad), from: twilioChannel.messages).startSync().getResult()

                for message in messages {
                    if message.author == TwilioHelper.shared.username {
                        continue
                    }

                     _ = try MessageProcessor.process(message: message, from: twilioChannel)
                }

                completion((), nil)
            } catch {
                completion(nil, error)
                Log.error("AAA: \(error.localizedDescription)")
            }
        }
    }

//    public static func addMembers(_ cards: [Card],
//                                  id: Int,
//                                  message: Message,
//                                  messageSender: MessageSender) -> CallbackOperation<Void> {
//        return CallbackOperation { _, completion in
//            do {
//                guard let twilioChannel = TwilioHelper.shared.currentChannel,
//                    let coreChannel = CoreDataHelper.shared.currentChannel else {
//                        throw NSError()
//                }
//
//                let identities = cards.map { $0.identity }
//
//                guard let session = VirgilHelper.shared.getGroupSession(of: coreChannel) else {
//                    completion((), nil)
//                    return
//                }
//
//                let ticket = try session.createChangeMembersTicket(add: cards, removeCardIds: [])
//
//                let serviceMessage = try ServiceMessage(message: ticket, type: .changeMembers, add: cards, remove: [])
//                let serialized = try serviceMessage.export()
//
//                let addTwilioMembersOperation = TwilioHelper.shared.addMembers(identities, to: twilioChannel)
//                let addCoreDataMembersOperation = CoreDataHelper.shared.makeAddOperation(cards, to: coreChannel)
//                let sendServiceMessageOperation = VirgilHelper.shared.makeSendServiceMessageOperation(cards: coreChannel.cards, ticket: serialized)
//                let sendChangeMembersOperation = messageSender.sendChangeMembers(message: message, withId: id)
//
//                let useTicketOperation = CallbackOperation<Void> { _, completion in
//                    do {
//                        try session.useChangeMembersTicket(ticket: ticket, addCards: cards, removeCardIds: [])
//                        try session.sessionStorage.storeSession(session)
//
//                        completion((), nil)
//                    } catch {
//                        completion(nil, error)
//                    }
//                }
//
//                let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)
//
//                let operations = [addTwilioMembersOperation,
//                                  addCoreDataMembersOperation,
//                                  sendServiceMessageOperation,
//                                  sendChangeMembersOperation,
//                                  useTicketOperation]
//
//                addCoreDataMembersOperation.addDependency(addTwilioMembersOperation)
//                sendChangeMembersOperation.addDependency(addTwilioMembersOperation)
//                useTicketOperation.addDependency(sendChangeMembersOperation)
//
//                operations.forEach {
//                    completionOperation.addDependency($0)
//                }
//
//                let queue = OperationQueue()
//                queue.addOperations(operations + [completionOperation], waitUntilFinished: false)
//            } catch {
//                completion(nil, error)
//            }
//        }
//    }
}
