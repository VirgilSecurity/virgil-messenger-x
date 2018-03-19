//
//  TwilioHelper+Channel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 3/5/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import TwilioChatClient

extension TwilioHelper {
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

    func joinChannels(_ channels: TCHChannels) {
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
                            guard let channelCore = CoreDataHelper.sharedInstance.createChannel(withName: identity, card: card.exportData()) else {
                                Log.error("failed to create new core data channel")
                                return
                            }
                            self.decryptFirstMessage(of: messages, channel: channelCore, saved: 0) { message, decryptedBody, decryptedMedia, messageDate in
                                guard let messageDate = messageDate else {
                                    return
                                }
                                if let decryptedBody = decryptedBody {
                                    CoreDataHelper.sharedInstance.createTextMessage(forChannel: channelCore, withBody: decryptedBody,
                                                                                    isIncoming: true, date: messageDate)
                                } else if let decryptedMedia = decryptedMedia {
                                    CoreDataHelper.sharedInstance.createMediaMessage(forChannel: channelCore, withData: decryptedMedia,
                                                                                     isIncoming: true, date: messageDate)
                                }

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
}
