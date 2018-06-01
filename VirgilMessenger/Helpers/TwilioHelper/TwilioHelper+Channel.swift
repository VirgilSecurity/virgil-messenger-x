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
    func createSingleChannel(with username: String, completion: @escaping (Error?) -> ()) {
        VirgilHelper.sharedInstance.getExportedCard(identity: username) { exportedCard, error in
            guard let exportedCard = exportedCard, error == nil else {
                Log.error("failed to add new channel card")
                DispatchQueue.main.async {
                    completion(error)
                }
                return
            }
            _ = CoreDataHelper.sharedInstance.createChannel(type: .single, name: username, cards: [exportedCard])

            TwilioHelper.sharedInstance.channels.createChannel(options: [
                TCHChannelOptionType: TCHChannelType.private.rawValue,
                TCHChannelOptionAttributes: [
                    Keys.initiator.rawValue: self.username,
                    Keys.responder.rawValue: username,
                    Keys.type.rawValue: ChannelType.single.rawValue
                ]
            ]) { result, channel in
                guard let channel = channel, result.isSuccessful() else {
                    Log.error("Error while creating chat with \(username): \(result.error?.localizedDescription ?? "")")
                    DispatchQueue.main.async {
                        completion(result.error)
                    }
                    CoreDataHelper.sharedInstance.deleteChannel(type: .single, name: username)
                    return
                }

                channel.members?.invite(byIdentity: username) { result in
                    guard result.isSuccessful() else {
                        Log.error("Error while inviting member \(username): \(result.error?.localizedDescription ?? "")")
                        DispatchQueue.main.async {
                            completion(result.error)
                        }
                        channel.destroy { result in
                            CoreDataHelper.sharedInstance.deleteChannel(type: .single, name: username)
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

    func createGlobalChannel(withName name: String, completion: @escaping (Error?) -> ()) {
        _ = CoreDataHelper.sharedInstance.createChannel(type: .group, name: name, cards: [])

        TwilioHelper.sharedInstance.channels.createChannel(options: [
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
                CoreDataHelper.sharedInstance.deleteChannel(type: .group, name: name)
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
                        VirgilHelper.sharedInstance.getExportedCard(identity: identity) { exportedCard, error in
                            guard let exportedCard = exportedCard, error == nil else {
                                Log.error("Getting new channel Card failed")
                                return
                            }
                            self.joinChannelHelper(name: identity, messages: messages, type: type, cards: [exportedCard])
                        }
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
                            let group = DispatchGroup()
                            for member in membersPaginator.items() {
                                guard let identity = member.identity else {
                                    Log.error("Member identity is unaccessable")
                                    return
                                }
                                group.enter()
                                VirgilHelper.sharedInstance.getExportedCard(identity: identity) { exportedCard, error in
                                    guard error == nil, let exportedCard = exportedCard else {
                                        return
                                    }
                                    cards.append(exportedCard)
                                    group.leave()
                                }
                            }

                            group.notify(queue: .main) {
                                self.joinChannelHelper(name: name, messages: messages, type: type, cards: cards)
                            }
                        }
                    }
                } else {
                    Log.error("Accepting invite to channel failed")
                }
            }
        }
    }

    func joinChannelHelper(name: String, messages: TCHMessages, type: ChannelType, cards: [String]) {
        guard let channelCore = CoreDataHelper.sharedInstance.createChannel(type: type, name: name, cards: cards) else {
            return
        }
        self.setLastMessage(of: messages, channel: channelCore) {
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: TwilioHelper.Notifications.ChannelAdded.rawValue),
                object: self,
                userInfo: [:])
        }

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

    func updateMembers(of channel: TCHChannel, coreChannel: Channel, completion: @escaping () -> ()) {
        channel.members?.members { result, membersPaginator in
            guard result.isSuccessful(), let membersPaginator = membersPaginator else {
                Log.error("Fetching members failed with: \(result.error?.localizedDescription ?? "unknown error")")
                completion()
                return
            }
            let group = DispatchGroup()
            for member in membersPaginator.items() {
                guard let identity = member.identity else {
                    Log.error("Member identity is unaccessable")
                    continue
                }
                if !CoreDataHelper.sharedInstance.doesHave(channel: coreChannel, member: identity) {
                    group.enter()
                    VirgilHelper.sharedInstance.getExportedCard(identity: identity) { exportedCard, error in
                        if error == nil, let exportedCard = exportedCard {
                            CoreDataHelper.sharedInstance.addMember(card: exportedCard, to: coreChannel)
                        }
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                completion()
            }
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
