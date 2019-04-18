//
//  Channel+CoreDataClass.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 12/15/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//
//

import CoreData
import VirgilSDK

@objc(Channel)
public class Channel: NSManagedObject {
    @NSManaged private var rawType: String
    @NSManaged private var numColorPair: Int32
    @NSManaged private var orderedMessages: NSOrderedSet?
    @NSManaged public var rawCards: [String]

    public var messages: [Message] {
        return self.orderedMessages?.array as? [Message] ?? []
    }

    public var cards: [Card] {
        get {
            let cards: [Card] = self.rawCards.map {
                try! VirgilHelper.shared.importCard(fromBase64Encoded: $0)
            }

            return cards
        }

        set {
            self.rawCards = newValue.map { try! $0.getRawCard().exportAsBase64EncodedString() }
        }
    }

    public var type: ChannelType {
        get {
            return ChannelType(rawValue: self.rawType) ?? .single
        }

        set {
            self.rawType = newValue.rawValue
        }
    }

    public var colorPair: ColorPair {
        return UIConstants.colorPairs[Int(self.numColorPair)]
    }

    public func setupColorPair() {
        self.numColorPair = Int32(arc4random_uniform(UInt32(UIConstants.colorPairs.count)))
    }

    public var lastMessagesBody: String {
        guard let message = self.messages.last else {
            return ""
        }

        switch message.type {
        case .text:
            return message.body ?? ""
        case .photo:
            return "Photo"
        case .audio:
            return "Voice Message"
        }
    }

    public var lastMessagesDate: Date? {
        guard let message = self.messages.last else {
            return nil
        }

        return message.date
    }

    public var letter: String {
        get {
            return String(describing: self.name.uppercased().first!)
        }
    }
}
