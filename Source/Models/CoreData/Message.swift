//
//  Message+CoreDataClass.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/16/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//
//

import CoreData
import ChattoAdditions

// TODO: split the file
@objc(Message)
public class Message: NSManagedObject, UIMessageModelExportable {
    @NSManaged public var xmppId: String
    @NSManaged public var date: Date
    @NSManaged public var isIncoming: Bool
    @NSManaged public var channel: Channel
    @NSManaged public var isHidden: Bool
    
    @NSManaged private var rawState: String
    
    // TODO: Remove isIncoming and rely on state only on migration/reset
    public enum State: String {
        case failed
        case received
        case sent
        case delivered
        case read
        
        func exportAsMessageStatus() -> MessageStatus {
            switch self {
            case .failed:
                return .failed
            case .sent:
                return .sent
            case .delivered:
                return .delivered
            case .read:
                return .read
            case .received:
                return .read
            }
        }
    }
    
    public var state: State {
        get {
            return State(rawValue: self.rawState) ?? .read
        }
        
        set {
            self.rawState = newValue.rawValue
        }
    }
    
    public struct Params {
        var xmppId: String
        var isIncoming: Bool
        var channel: Channel
        var state: State
        var date: Date = Date()
        var isHidden: Bool = false
    }
    
    convenience public init(entityName: String, context: NSManagedObjectContext, params: Params) throws {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            throw CoreData.Error.entityNotFound
        }
        
        self.init(entity: entity, insertInto: context)
        
        self.xmppId = params.xmppId
        self.isIncoming = params.isIncoming
        self.channel = params.channel
        self.date = params.date
        self.isHidden = params.isHidden
        self.rawState = params.state.rawValue
    }
        
    public func exportAsUIModel(withId id: Int) -> UIMessageModelProtocol {
        Log.error(CoreData.Error.exportBaseMessageForbidden,
                  message: "Exporting abstract Message to UI model is forbidden")
        
        return UITextMessageModel.corruptedModel(uid: id,
                                                 isIncoming: self.isIncoming,
                                                 date: self.date)
    }
}
