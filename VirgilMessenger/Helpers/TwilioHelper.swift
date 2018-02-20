//
//  TwilioHelper.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import TwilioChatClient

class TwilioHelper: NSObject {
    private(set) static var sharedInstance: TwilioHelper!
    private(set) var client: TwilioChatClient!
    private(set) var channels: TCHChannels!
    private(set) var users: TCHUsers!
    private(set) var currentChannel: TCHChannel!

    let username: String
    private let queue = DispatchQueue(label: "TwilioHelper")
    private let device: String
    private let connection = ServiceConnection()

    enum TwilioHelperError: Int, Error {
        case initFailed
        case initChannelsFailed
        case initUsersFailed
        case joiningFailed
    }

    static func authorize(username: String, device: String) {
        self.sharedInstance = TwilioHelper(username: username, device: device)
    }

    private init(username: String, device: String) {
        self.username = username
        self.device = device

        super.init()
    }

    func initialize(token: String, completion: @escaping (Error?) -> ()) {
        Log.debug("Initializing Twilio")

        self.queue.async {
            TwilioChatClient.chatClient(withToken: token, properties: nil, delegate: self) { result, client in
                guard let client = client, result.isSuccessful() else {
                    Log.error("Error while initializing Twilio: \(result.error?.localizedDescription ?? "")")
                    completion(TwilioHelperError.initFailed)
                    return
                }

                guard let channels = client.channelsList() else {
                    Log.error("Error while initializing Twilio channels")
                    completion(TwilioHelperError.initChannelsFailed)
                    return
                }

                guard let users = client.users() else {
                    Log.error("Error while initializing Twilio users")
                    completion(TwilioHelperError.initUsersFailed)
                    return
                }

                Log.debug("Successfully initialized Twilio")
                self.client = client
                self.channels = channels
                self.users = users

                self.joinChannels(channels)
                completion(nil)
            }
        }
    }

    private func joinChannels(_ channels: TCHChannels) {
        for channel in channels.subscribedChannels() {
            if channel.status == TCHChannelStatus.invited {
                channel.join() { channelResult in
                    if channelResult.isSuccessful(),
                        let messages = channel.messages {

                        Log.debug("Successfully accepted invite.")
                        let identity = self.getCompanion(ofChannel: channel)
                        Log.debug("identity: \(identity)")
                        VirgilHelper.sharedInstance.getCard(withIdentity: identity) { card, error in
                            guard let card = card, error == nil else {
                                Log.error("failed to get new channel card")
                                return
                            }
                            guard let channelCore = CoreDataHelper.sharedInstance.createChannel(withName: identity,
                                                                                                    card: card.exportData()) else {
                                Log.error("failed to create new core data channel")
                                return
                            }
                            self.decryptFirstMessage(of: messages, channel: channelCore, saved: 0) { message, decryptedMessageBody, messageDate in
                                guard let decryptedMessageBody = decryptedMessageBody,
                                    let messageDate = messageDate else {
                                        return
                                }
                                CoreDataHelper.sharedInstance.createMessage(forChannel: channelCore, withBody: decryptedMessageBody,
                                                                            isIncoming: true, date: messageDate)
                                self.setLastMessage(of: messages, channel: channelCore) {
                                    NotificationCenter.default.post(
                                        name: Notification.Name(rawValue: TwilioHelper.Notifications.ChannelAdded.rawValue),
                                        object: self,
                                        userInfo: [:])
                                }
                            }

                            Log.debug("new card added")
                            NotificationCenter.default.post(
                                name: Notification.Name(rawValue: TwilioHelper.Notifications.ChannelAdded.rawValue),
                                object: self,
                                userInfo: [:])
                        }
                    } else {
                        Log.error("Failed to accept invite.")
                    }
                }
            }
        }
    }

    func setChannel(withUsername username: String) {
        for channel in channels.subscribedChannels() {
            if getCompanion(ofChannel: channel) == username {
                self.currentChannel = channel
                return
            }
        }
    }

    func createChannel(withUsername username: String, completion: @escaping (Error?) -> ()) {
        VirgilHelper.sharedInstance.getCard(withIdentity: username) { card, error in
            guard let card = card, error == nil else {
                Log.error("failed to add new channel card")
                DispatchQueue.main.async {
                    completion(error)
                }
                return
            }
            _ = CoreDataHelper.sharedInstance.createChannel(withName: username, card: card.exportData())

            TwilioHelper.sharedInstance.channels.createChannel(options: [
                TCHChannelOptionType: TCHChannelType.private.rawValue,
                TCHChannelOptionAttributes: [
                    "initiator": self.username,
                    "responder": username
                ]
            ]) { result, channel in
                guard let channel = channel, result.isSuccessful() else {
                    Log.error("Error while creating chat with \(username): \(result.error?.localizedDescription ?? "")")
                    DispatchQueue.main.async {
                        completion(result.error)
                    }
                    CoreDataHelper.sharedInstance.deleteChannel(withName: username)
                    return
                }

                channel.members?.invite(byIdentity: username) { result in
                    guard result.isSuccessful() else {
                        Log.error("Error while inviting member \(username): \(result.error?.localizedDescription ?? "")")
                        DispatchQueue.main.async {
                            completion(result.error)
                        }
                        channel.destroy { result in
                            CoreDataHelper.sharedInstance.deleteChannel(withName: username)
                            guard result.isSuccessful() else {
                                Log.error("can't destroy channel")
                                return
                            }
                        }
                        return
                    }
                }

                channel.join(completion: { channelResult in
                    if channelResult.isSuccessful() {
                        Log.debug("Channel joined.")
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                    } else {
                        Log.error("Channel NOT joined.")
                        DispatchQueue.main.async {
                            completion(TwilioHelperError.joiningFailed)
                        }
                    }
                })
            }
        }
    }

    func setLastMessage(of messages: TCHMessages, channel: Channel, completion: @escaping () -> ()) {
        messages.getLastWithCount(UInt(1)) { result, messages in
            if  let messages = messages,
                let message = messages.last,
                let messageBody = message.body,
                let messageDate = message.dateUpdatedAsDate,
                message.author != TwilioHelper.sharedInstance.username,
                let stringCard = channel.card,
                let card = VirgilHelper.sharedInstance.buildCard(stringCard),
                let secureChat = VirgilHelper.sharedInstance.secureChat {
                do {
                    let session = try secureChat.loadUpSession(withParticipantWithCard: card, message: messageBody)
                    let decryptedMessageBody = try session.decrypt(messageBody)

                    channel.lastMessagesBody = decryptedMessageBody
                    channel.lastMessagesDate = messageDate
                } catch {
                    Log.error("decryption process failed: \(error.localizedDescription)")
                }
            }

            completion()
        }
    }

    func decryptFirstMessage(of messages: TCHMessages, channel: Channel, saved: Int, completion: @escaping (TCHMessage?, String?, Date?) -> ()) {
        messages.getBefore(UInt(saved), withCount: 1) { result, oneMessages in
            guard let oneMessages = oneMessages,
                let message = oneMessages.first,
                let messageBody = message.body,
                let messageDate = message.dateUpdatedAsDate,
                message.author != TwilioHelper.sharedInstance.username,
                let stringCard = channel.card,
                let card = VirgilHelper.sharedInstance.buildCard(stringCard),
                let secureChat = VirgilHelper.sharedInstance.secureChat else {
                    completion(nil, nil, nil)
                    return
            }
            do {
                let session = try secureChat.loadUpSession(withParticipantWithCard: card, message: messageBody)
                let decryptedMessageBody = try session.decrypt(messageBody)

                channel.lastMessagesBody = decryptedMessageBody
                channel.lastMessagesDate = messageDate

                completion(message, decryptedMessageBody, messageDate)
            } catch {
                Log.error("decryption process of first message failed: \(error.localizedDescription)")
                completion(nil, nil, nil)
            }
        }
    }

    func getLastMessages(count: Int, completion: @escaping ([DemoTextMessageModel?]) -> ()) {
        var ret = [DemoTextMessageModel]()
        guard let messages = self.currentChannel.messages else {
            Log.error("nil messages in selected channel")
            completion(ret)
            return
        }

        messages.getLastWithCount(UInt(count), completion: { result, messages in
            guard let messages = messages else {
                Log.error("Twilio can't get last messages")
                completion(ret)
                return
            }
            for message in messages {
                guard let messageBody = message.body,
                      let messageDate = message.dateUpdatedAsDate
                else {
                    Log.error("wrong message atributes")
                    completion(ret)
                    return
                }
                let isIncoming = message.author == self.username ? false : true
                let textMessageModel = createTextMessageModel("\(ret.count)", text: messageBody, isIncoming: isIncoming,
                                                              status: .success, date: messageDate)
                ret.append(textMessageModel)
            }
            completion(ret)
        })
    }

    func getMessages(before: Int, withCount: Int, completion: @escaping ([DemoTextMessageModel?]) -> ()) {
        var ret = [DemoTextMessageModel]()
        guard let messages = self.currentChannel.messages else {
            Log.error("nil messages in selected channel")
            completion(ret)
            return
        }
        messages.getBefore(UInt(before), withCount: UInt(withCount), completion: { result, messages in
            guard let messages = messages else {
                Log.error("Twilio can't get last messages")
                completion(ret)
                return
            }
            for message in messages {
                guard let messageBody = message.body,
                    let messageDate = message.dateUpdatedAsDate
                    else {
                        Log.error("wrong message atributes")
                        completion(ret)
                        return
                }
                let isIncoming = message.author == self.username ? false : true
                ret.append(createTextMessageModel("\(ret.count)", text: messageBody, isIncoming: isIncoming, status: .success, date: messageDate))
            }
            completion(ret)
        })
    }

    func destroyChannel(_ number: Int, completion: @escaping () -> ()) {
        let channel = self.channels.subscribedChannels()[number]
        channel.destroy { result in
            completion()
            guard result.isSuccessful() else {
                Log.error("can't destroy channel")
                return
            }
        }
    }

    func getCompanion(ofChannel: Int) -> String {
        let channel = self.channels.subscribedChannels()[ofChannel]
        guard let attributes = channel.attributes(),
            let initiator = attributes["initiator"] as? String,
            let responder = attributes["responder"] as? String
            else {
                Log.error("Error: Didn't find channel attributes")
                return "Error name"
        }

        let result = initiator == self.username ? responder : initiator
        return result
    }

    func getCompanion(ofChannel channel: TCHChannel) -> String {
        guard let attributes = channel.attributes(),
            let initiator = attributes["initiator"] as? String,
            let responder = attributes["responder"] as? String
            else {
                Log.error("Error: Didn't find channel attributes")
                return "Error name"
        }

        let result = initiator == self.username ? responder : initiator
        return result
    }

    func deselectChannel() {
        self.currentChannel = nil
    }
}
