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
    func getAttributes(of channel: TCHChannel) throws -> ChannelAttributes {
        guard let attributes = channel.attributes() else {
            throw TwilioHelperError.missingChannelAttributes
        }

        return try ChannelAttributes.import(attributes)
    }

    func makeJoinOperation(channel: TCHChannel) -> CallbackOperation<Void> {
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

    func makeJoinOperation() -> CallbackOperation<Void> {
        return CallbackOperation { operation, completion in
            do {
                let channel: TCHChannel = try operation.findDependencyResult()

                self.makeJoinOperation(channel: channel).start(completion: completion)
            } catch {
                completion(nil, error)
            }
        }
    }

    private func makeCreateChannelOperation(with options: [String: Any]) -> CallbackOperation<TCHChannel> {
        return CallbackOperation { _, completion in
            self.channels.createChannel(options: options) { result, channel in
                guard result.isSuccessful() else {
                    completion(nil, result.error)
                    return
                }

                completion(channel, nil)
            }
        }
    }

    private func makeInviteOperation(identity: String) -> CallbackOperation<Void> {
        return CallbackOperation { operation, completion in
            do {
                let channel: TCHChannel = try operation.findDependencyResult()

                channel.members?.invite(byIdentity: identity) { result in
                    guard result.isSuccessful() else {
                        completion(nil, result.error)
                        return
                    }

                    completion((), nil)
                }
            } catch {
                completion(nil, error)
            }
        }
    }

    func makeCreateChannelOperation(with identity: String) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            let attributes = ChannelAttributes(initiator: self.username, responder: identity, type: .single)

            let options: [String: Any] = [TCHChannelOptionType: TCHChannelType.private.rawValue,
                                          TCHChannelOptionAttributes: try! attributes.export()]

            Log.debug("\(options)")
            Log.debug("\(try! attributes.export())")

            let createChannelOperation = self.makeCreateChannelOperation(with: options)
            let inviteOperation = self.makeInviteOperation(identity: identity)
            let joinOperation = self.makeJoinOperation()
            let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

            inviteOperation.addDependency(createChannelOperation)
            joinOperation.addDependency(createChannelOperation)

            let operations = [createChannelOperation,
                              inviteOperation,
                              joinOperation]

            operations.forEach {
                completionOperation.addDependency($0)
            }

            let queue = OperationQueue()
            queue.addOperations(operations + [completionOperation], waitUntilFinished: false)
        }
    }

    func getName(of channel: TCHChannel) -> String {
        // FIXME
        guard let attributes = try? self.getAttributes(of: channel) else {
            return "Error name"
        }

        switch attributes.type {
        case .single:
            return self.getCompanion(of: channel)
        case .group:
            return channel.friendlyName ?? "Error name"
        }
    }

    //    func createGlobalChannel(withName name: String, completion: @escaping (Error?) -> ()) {
    //        TwilioHelper.shared.channels.createChannel(options: [
    //            TCHChannelOptionType: TCHChannelType.private.rawValue,
    //            TCHChannelOptionFriendlyName: name,
    //            TCHChannelOptionAttributes: [
    //                Keys.initiator.rawValue: self.username,
    //                Keys.type.rawValue: ChannelType.group.rawValue
    //            ]
    //        ]) { result, channel in
    //            guard let channel = channel, result.isSuccessful() else {
    //                Log.error("Error while creating group chat: \(result.error?.localizedDescription ?? "")")
    //                DispatchQueue.main.async {
    //                    completion(result.error)
    //                }
    //                return
    //            }
    //
    //            channel.join(completion: { channelResult in
    //                if channelResult.isSuccessful() {
    //                    Log.debug("Channel joined.")
    //                    DispatchQueue.main.async {
    //                        completion(nil)
    //                    }
    //                } else {
    //                    Log.error("Channel NOT joined.")
    //                    DispatchQueue.main.async {
    //                        completion(TwilioHelperError.joiningFailed)
    //                    }
    //                    channel.destroy { result in
    //                        guard result.isSuccessful() else {
    //                            Log.error("can't destroy channel")
    //                            return
    //                        }
    //                    }
    //                }
    //            })
    //        }
    //    }
}
