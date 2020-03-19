//
//  Storage+Messages.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import CoreData
import VirgilCryptoRatchet
import VirgilSDK
import ChattoAdditions

extension Storage {
    @objc(Message)
    public class Message: NSManagedObject {
        @NSManaged public var date: Date
        @NSManaged public var isIncoming: Bool
        @NSManaged public var channel: Storage.Channel
        @NSManaged public var isHidden: Bool
    }
}

extension Storage.Message {
    public func exportAsUIModel(withId id: Int, status: MessageStatus = .success) -> UIMessageModelProtocol {
        let resultMessage: UIMessageModelProtocol

        if let message = self as? Storage.TextMessage {
            resultMessage = UITextMessageModel(uid: id,
                                               text: message.body,
                                               isIncoming: self.isIncoming,
                                               status: status,
                                               date: date)
        }
        else if let call = self as? Storage.CallMessage {
            let text = call.isIncoming ? "Incomming call from \(call.channelName)" : "Outgoing call to \(call.channelName)"
            resultMessage = UITextMessageModel(uid: id,
                                               text: text,
                                               isIncoming: self.isIncoming,
                                               status: status,
                                               date: date)
        }
        else {
            Log.error("Exporting core data model to ui model failed")

            resultMessage = UITextMessageModel.corruptedModel(uid: id,
                                                              isIncoming: self.isIncoming,
                                                              date: self.date)
        }

        return resultMessage
    }
}

extension Storage {
    private func save(_ message: Storage.Message) throws {
        let messages = message.channel.mutableOrderedSetValue(forKey: Storage.Channel.MessagesKey)
        messages.add(message)

        try self.saveContext()
    }

    func createEncryptedMessage(in channel: Storage.Channel, isIncoming: Bool, date: Date) throws {
        let message = try Storage.TextMessage(body: "Message encrypted",
                                      isIncoming: isIncoming,
                                      date: date,
                                      channel: channel,
                                      isHidden: true,
                                      managedContext: self.managedContext)

        try self.save(message)
    }

    func createTextMessage(_ body: String,
                           in channel: Storage.Channel? = nil,
                           isIncoming: Bool,
                           date: Date = Date()) throws -> Storage.Message {
        let channel = try channel ?? self.getCurrentChannel()

        let message = try Storage.TextMessage(body: body,
                                      isIncoming: isIncoming,
                                      date: date,
                                      channel: channel,
                                      managedContext: self.managedContext)

        try self.save(message)

        return message
    }

    func createCallMessage(in channel: Storage.Channel? = nil,
                           isIncoming: Bool,
                           date: Date = Date()) throws -> Storage.Message {
        let channel = try channel ?? self.getCurrentChannel()

        let message = try Storage.CallMessage(isIncoming: isIncoming,
                                      date: date,
                                      channel: channel,
                                      managedContext: self.managedContext)

        try self.save(message)

        return message
    }
}
