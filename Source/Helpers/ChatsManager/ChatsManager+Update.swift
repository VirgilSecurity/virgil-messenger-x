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

                    let coreGroupChannels = CoreData.shared.getGroupChannels()

                    for coreChannel in coreGroupChannels {
                        if (try? Twilio.shared.getChannel(coreChannel)) == nil {
                            try Virgil.ethree.deleteGroup(id: coreChannel.sid).startSync().get()
                            try CoreData.shared.delete(channel: coreChannel)
                        }
                    }

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
                let attributes = try twilioChannel.getAttributes()

                // Update CoreData
                let coreChannel = try self.updateCoreData(with: twilioChannel)

                if attributes.type == .group {
                    // Update Virgil Group
                    let group = try self.updateVirgilGroup(with: coreChannel,
                                                           initiator: attributes.initiator)
                    coreChannel.set(group: group)
                }

                // Load, decrypt and save messeges
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

                    _ = try MessageProcessor.process(message: message, from: twilioChannel, coreChannel: coreChannel)
                }

                completion((), nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }

    private static func updateVirgilGroup(with coreChannel: Channel,
                                          initiator: String) throws -> Group {
        let group: Group

        if let cachedGroup = try Virgil.ethree.getGroup(id: coreChannel.sid) {
            group = cachedGroup
        }
        else {
            do {
                group = try Virgil.ethree.loadGroup(id: coreChannel.sid, initiator: initiator)
                    .startSync()
                    .get()
            }
            catch GroupError.groupWasNotFound {
                if initiator == Virgil.ethree.identity {
                    var result = FindUsersResult()
                    coreChannel.cards.forEach {
                        result[$0.identity] = $0
                    }

                    group = try Virgil.ethree.createGroup(id: coreChannel.sid, with: result)
                        .startSync()
                        .get()
                }
                else {
                    throw GroupError.groupWasNotFound
                }
            }
        }

        return group
    }

    private static func updateCoreData(with twilioChannel: TCHChannel) throws -> Channel {
        let coreChannel: Channel
        if let channel = try? CoreData.shared.getChannel(twilioChannel) {
            coreChannel = channel
        }
        else {
            let sid = try twilioChannel.getSid()
            let attributes = try twilioChannel.getAttributes()

            switch attributes.type {
            case .single:
                let name = try Twilio.shared.getCompanion(from: attributes)

                let card = try Virgil.ethree.findUser(with: name).startSync().get()

                coreChannel = try CoreData.shared.createSingleChannel(sid: sid,
                                                                      initiator: attributes.initiator,
                                                                      card: card)
            case .group:
                let result = try Virgil.ethree.findUsers(with: Array(attributes.members)).startSync().get()
                let cards = Array(result.values)

                let name = try twilioChannel.getFriendlyName()

                coreChannel = try CoreData.shared.createGroupChannel(name: name,
                                                                     sid: sid,
                                                                     initiator: attributes.initiator,
                                                                     cards: cards)
            }
        }

        return coreChannel
    }
}
