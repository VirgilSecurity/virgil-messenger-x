//
//  Strage+VoiceMessage.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/16/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//
//

import Foundation
import CoreData
import ChattoAdditions

extension Storage {
    @objc(VoiceMessage)
    public class VoiceMessage: Message {
        @NSManaged public var identifier: String
        @NSManaged public var url: URL
        @NSManaged public var duration: Double

        private static let EntityName = "VoiceMessage"

        convenience init(identifier: String,
                         duration: Double,
                         url: URL,
                         xmppId: String,
                         isIncoming: Bool,
                         date: Date,
                         channel: Channel,
                         isHidden: Bool = false,
                         managedContext: NSManagedObjectContext) throws {
            guard let entity = NSEntityDescription.entity(forEntityName: VoiceMessage.EntityName,
                                                          in: managedContext) else {
                throw Storage.Error.entityNotFound
            }

            self.init(entity: entity, insertInto: managedContext)

            self.identifier = identifier
            self.duration = duration
            self.url = url
            self.xmppId = xmppId
            self.isIncoming = isIncoming
            self.date = date
            self.channel = channel
            self.isHidden = isHidden
        }

        public override func exportAsUIModel(withId id: Int, status: MessageStatus = .success) -> UIMessageModelProtocol {
            do {
                let mediaStorage = try Storage.shared.getMediaStorage()

                let audioUrl = try mediaStorage.getURL(name: self.identifier, type: .voice)
                let state: MediaMessageState = mediaStorage.exists(path: audioUrl.path) ? .normal : .downloading

                let uiModel = UIAudioMessageModel(uid: id,
                                                  audioUrl: audioUrl,
                                                  duration: TimeInterval(self.duration),
                                                  isIncoming: self.isIncoming,
                                                  status: status,
                                                  state: state,
                                                  date: self.date)
                if state == .downloading {
                    try Virgil.shared.client.startDownload(from: self.url,
                                                           loadDelegate: uiModel,
                                                           dataHash: self.identifier) { tempFileUrl in
                        guard let inputStream = InputStream(url: tempFileUrl) else {
                            throw Client.Error.inputStreamFromDownloadedFailed
                        }

                        guard let outputStream = OutputStream(toFileAtPath: audioUrl.path, append: false) else {
                            throw FileMediaStorage.Error.outputStreamToPathFailed
                        }

                        // TODO: add self card usecase
                        try Virgil.ethree.authDecrypt(inputStream, to: outputStream, from: self.channel.getCard())
                    }
                }

                return uiModel
            } catch {
                Log.error(error, message: "Exporting AudioMessage to UI model failed")

                return UITextMessageModel.corruptedModel(uid: id,
                                                         isIncoming: self.isIncoming,
                                                         date: self.date)
            }
        }
    }
}
