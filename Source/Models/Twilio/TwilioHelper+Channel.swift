//
//  TwilioHelper+Channel.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 3/5/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Foundation
import TwilioChatClient
import VirgilSDK

extension TwilioHelper {
    private func makeInviteOperation(channel: TCHChannel, identity: String) -> GenericOperation<Void> {
        return CallbackOperation { _, completion in
            channel.members?.invite(byIdentity: identity) { result in
                guard result.isSuccessful() else {
                    completion(nil, result.error)
                    return
                }

                completion((), nil)
            }
        }
    }

    private func makeJoinOperation(channel: TCHChannel) -> GenericOperation<Void> {
        return CallbackOperation { _, completion in
            channel.join { result in
                guard result.isSuccessful() else {
                    completion(nil, TwilioHelperError.joiningFailed)
                    return
                }

                completion((), nil)
            }
        }
    }

    func createSingleChannel(with identity: String) -> GenericOperation<Void> {
        return CallbackOperation { _, completion in
            let attributes = [Keys.initiator.rawValue: self.username,
                              Keys.responder.rawValue: identity,
                              Keys.type.rawValue: ChannelType.single.rawValue]

            let options: [String: Any] = [TCHChannelOptionType: TCHChannelType.private.rawValue,
                                          TCHChannelOptionAttributes: attributes]

            self.channels.createChannel(options: options) { result, channel in
                guard let channel = channel, result.isSuccessful() else {
                    Log.error("Twilio: Error while creating chat with \(identity): \(result.error?.localizedDescription ?? "")")
                    completion(nil, result.error)
                    return
                }

                channel.members?.invite(byIdentity: identity) { result in
                    guard result.isSuccessful() else {
                        completion(nil, result.error)
                        return
                    }

                    channel.join { result in
                        guard result.isSuccessful() else {
                            completion(nil, TwilioHelperError.joiningFailed)
                            return
                        }

                        completion((), nil)
                    }
                }
            }
        }
    }

    func createGlobalChannel(withName name: String, completion: @escaping (Error?) -> ()) {
        TwilioHelper.shared.channels.createChannel(options: [
            TCHChannelOptionType: TCHChannelType.private.rawValue,
            TCHChannelOptionFriendlyName: name,
            TCHChannelOptionAttributes: [
                Keys.initiator.rawValue: self.username,
                Keys.type.rawValue: ChannelType.group.rawValue
            ]
        ]) { result, channel in
            guard let channel = channel, result.isSuccessful() else {
                Log.error("Error while creating group chat: \(result.error?.localizedDescription ?? "")")
                DispatchQueue.main.async {
                    completion(result.error)
                }
                return
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
                    channel.destroy { result in
                        guard result.isSuccessful() else {
                            Log.error("can't destroy channel")
                            return
                        }
                    }
                }
            })
        }
    }

    func join(channel: TCHChannel) {
        if channel.status == TCHChannelStatus.invited {
            channel.join() { channelResult in
                if channelResult.isSuccessful(), let messages = channel.messages {
                    guard let type = self.getType(of: channel) else {
                        return
                    }
                    Log.debug("Successfully accepted invite to \(type.rawValue) channel")

                    switch type {
                    case .single:
                        let identity = self.getCompanion(of: channel)
                        let card = try! VirgilHelper.shared.getCard(identity: identity).startSync().getResult()
                        self.joinChannelHelper(name: identity, messages: messages, type: type, cards: [card])
                    case .group:
                        guard let name = channel.friendlyName else {
                            Log.error("Missing global name of channel")
                            return
                        }
                        channel.members?.members { result, membersPaginator in
                            guard result.isSuccessful(), let membersPaginator = membersPaginator else {
                                Log.error("Fetching members failed with: \(result.error?.localizedDescription ?? "unknown error")")
                                return
                            }
                            var cards: [String] = []
                            for member in membersPaginator.items() {
                                guard let identity = member.identity else {
                                    Log.error("Member identity is unaccessable")
                                    return
                                }

                                let card = try! VirgilHelper.shared.getCard(identity: identity).startSync().getResult()
                                cards.append(card)
                            }

                            self.joinChannelHelper(name: name, messages: messages, type: type, cards: cards)
                        }
                    }
                } else {
                    Log.error("Accepting invite to channel failed")
                }
            }
        }
    }

    func joinChannelHelper(name: String, messages: TCHMessages, type: ChannelType, cards: [String]) {
        CoreDataHelper.shared.createChannel(type: type, name: name, cards: cards)

//
//        self.setLastMessage(of: messages, channel: channelCore) {
//            NotificationCenter.default.post(
//                name: Notification.Name(rawValue: TwilioHelper.Notifications.ChannelAdded.rawValue),
//                object: self,
//                userInfo: [:])
//        }

        NotificationCenter.default.post(
            name: Notification.Name(rawValue: TwilioHelper.Notifications.ChannelAdded.rawValue),
            object: self,
            userInfo: [:])
    }

    func getName(of channel: TCHChannel) -> String? {
        guard let type = self.getType(of: channel) else {
            return "Error name"
        }

        switch type {
        case .single:
            return self.getCompanion(of: channel)
        case .group:
            return channel.friendlyName ?? "Error name"
        }
    }

    func invite(member username: String, completion: @escaping (Error?) -> ()) {
        currentChannel.members?.invite(byIdentity: username) { result in
            if !result.isSuccessful() {
                Log.error("Error while inviting member \(username): \(result.error?.localizedDescription ?? "")")
            }
            DispatchQueue.main.async {
                completion(result.error)
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
