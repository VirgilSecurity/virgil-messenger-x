//
//  Message+CoreDataClass.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/16/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//
//

import CoreData
import UIKit
import AVFoundation

@objc(Message)
public class Message: NSManagedObject {
    @NSManaged public var body: String?
    @NSManaged public var date: Date
    @NSManaged public var isIncoming: Bool
    @NSManaged public var media: Data?
    @NSManaged public var channel: Channel

    @NSManaged private var rawType: String

    private static let EntityName = "Message"

    public var type: MessageType {
        get {
            return MessageType(rawValue: self.rawType) ?? .text
        }

        set {
            self.rawType = newValue.rawValue
        }
    }

    convenience init(body: String? = nil,
                     media: Data? = nil,
                     type: MessageType,
                     isIncoming: Bool,
                     date: Date,
                     managedContext: NSManagedObjectContext) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: Message.EntityName, in: managedContext) else {
            throw CoreDataHelperError.entityNotFound
        }

        self.init(entity: entity, insertInto: managedContext)

        self.body = body
        self.media = media
        self.type = type
        self.isIncoming = isIncoming
        self.date = date
    }
}

extension Message {
    public func exportAsUIModel(withId id: Int) -> DemoMessageModelProtocol {
        let corruptedMessage = {
            MessageFactory.createCorruptedMessageModel(uid: id, isIncoming: self.isIncoming)
        }

        let resultMessage: DemoMessageModelProtocol

        switch self.type {
        case .text:
            guard let body = self.body else {
                return corruptedMessage()
            }

            resultMessage = MessageFactory.createTextMessageModel(uid: id,
                                                                  text: body,
                                                                  isIncoming: self.isIncoming,
                                                                  status: .success,
                                                                  date: date)
        case .photo:
            guard let media = self.media, let image = UIImage(data: media) else {
                return corruptedMessage()
            }

            resultMessage = MessageFactory.createPhotoMessageModel(uid: id,
                                                                   image: image,
                                                                   size: image.size,
                                                                   isIncoming: self.isIncoming,
                                                                   status: .success,
                                                                   date: date)
        case .audio:
            guard let media = self.media, let duration = try? AVAudioPlayer(data: media).duration else {
                return corruptedMessage()
            }

            resultMessage = MessageFactory.createAudioMessageModel(uid: id,
                                                                   audio: media,
                                                                   duration: duration,
                                                                   isIncoming: self.isIncoming,
                                                                   status: .success,
                                                                   date: date)
        }

        return resultMessage
    }
}
