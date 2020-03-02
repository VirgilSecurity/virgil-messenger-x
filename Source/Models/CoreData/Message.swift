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
import ChattoAdditions

@objc(Message)
public class Message: NSManagedObject {
    @NSManaged public var body: String?
    @NSManaged public var date: Date
    @NSManaged public var isIncoming: Bool
    @NSManaged public var media: Data?
    @NSManaged public var channel: Channel
    @NSManaged public var isHidden: Bool

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

    func getBody() throws -> String {
        guard let body = self.body else {
            throw CoreData.Error.invalidMessage
        }

        return body
    }

    convenience init(body: String? = nil,
                     media: Data? = nil,
                     type: MessageType,
                     isIncoming: Bool,
                     date: Date,
                     channel: Channel,
                     isHidden: Bool = false,
                     managedContext: NSManagedObjectContext) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: Message.EntityName, in: managedContext) else {
            throw CoreData.Error.entityNotFound
        }

        self.init(entity: entity, insertInto: managedContext)

        self.body = body
        self.media = media
        self.type = type
        self.isIncoming = isIncoming
        self.date = date
        self.channel = channel
        self.isHidden = isHidden
    }
}

extension Message {
    public func exportAsUIModel(withId id: Int, status: MessageStatus = .success) -> UIMessageModelProtocol {
        let corruptedMessage = {
            UITextMessageModel.corruptedModel(uid: id, isIncoming: self.isIncoming, date: self.date)
        }

        let resultMessage: UIMessageModelProtocol

        switch self.type {
        case .text:
            guard let body = self.body else {
                return corruptedMessage()
            }

            resultMessage = UITextMessageModel(uid: id,
                                               text: body,
                                               isIncoming: self.isIncoming,
                                               status: status,
                                               date: date)
        case .photo:
            guard let media = self.media, let image = UIImage(data: media) else {
                return corruptedMessage()
            }

            resultMessage = UIPhotoMessageModel(uid: id,
                                                image: image,
                                                isIncoming: self.isIncoming,
                                                status: status,
                                                date: date)
        case .audio:
            guard let media = self.media, let duration = try? AVAudioPlayer(data: media).duration else {
                return corruptedMessage()
            }

            resultMessage = UIAudioMessageModel(uid: id,
                                                audio: media,
                                                duration: duration,
                                                isIncoming: self.isIncoming,
                                                status: status,
                                                date: date)
        }

        return resultMessage
    }
}
