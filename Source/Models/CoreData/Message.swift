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
    @NSManaged public var channel: Channel
    @NSManaged public var isHidden: Bool
    @NSManaged public var mediaHash: String?
    @NSManaged public var mediaUrl: URL?

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
                     type: MessageType,
                     isIncoming: Bool,
                     date: Date,
                     channel: Channel,
                     isHidden: Bool = false,
                     mediaHash: String? = nil,
                     mediaUrl: URL? = nil,
                     managedContext: NSManagedObjectContext) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: Message.EntityName, in: managedContext) else {
            throw CoreData.Error.entityNotFound
        }

        self.init(entity: entity, insertInto: managedContext)

        self.body = body
        self.type = type
        self.isIncoming = isIncoming
        self.date = date
        self.channel = channel
        self.isHidden = isHidden
        self.mediaHash = mediaHash
        self.mediaUrl = mediaUrl
    }
    
    func getBody() throws -> String {
        guard let body = self.body else {
            throw CoreData.Error.invalidMessage
        }

        return body
    }
    
    func getMediaUrl() throws -> URL {
        guard let mediaUrl = self.mediaUrl else {
            throw CoreData.Error.invalidMessage
        }
        
        return mediaUrl
    }
    
    func getMediaHash() throws -> String {
        guard let mediaHash = self.mediaHash else {
            throw CoreData.Error.invalidMessage
        }
        
        return mediaHash
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
                                               date: self.date)
        case .photo:
            // FIXME: Add error loging
            let path1 = try! CoreData.shared.getMediaStorage().getPath(name: self.getMediaHash())
            Log.debug("AAA: \(path1))")
            guard let path = try? CoreData.shared.getMediaStorage().getPath(name: self.getMediaHash()),
                let image = UIImage(contentsOfFile: path) else {
                    return corruptedMessage()
            }
            
            resultMessage = UIPhotoMessageModel(uid: id,
                                                image: image,
                                                isIncoming: self.isIncoming,
                                                status: status,
                                                date: self.date)
//        case .audio:
//            guard let media = self.media, let duration = try? AVAudioPlayer(data: media).duration else {
//                return corruptedMessage()
//            }
//
//            resultMessage = UIAudioMessageModel(uid: id,
//                                                audio: media,
//                                                duration: duration,
//                                                isIncoming: self.isIncoming,
//                                                status: status,
//                                                date: date)
        default:
            // FIXME
            fatalError()
        }
        

        return resultMessage
    }
}
