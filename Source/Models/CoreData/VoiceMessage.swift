//
//  VoiceMessage.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/16/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//
//

import Foundation
import CoreData
import ChattoAdditions

@objc(VoiceMessage)
public class VoiceMessage: Message {
    @NSManaged public var identifier: String
    @NSManaged public var url: URL
    @NSManaged public var duration: Double

    private static let EntityName = "VoiceMessage"

    convenience init(identifier: String,
                     duration: Double,
                     url: URL,
                     baseParams: Message.Params,
                     context: NSManagedObjectContext) throws {
        try self.init(entityName: VoiceMessage.EntityName, context: context, params: baseParams)

        self.identifier = identifier
        self.duration = duration
        self.url = url
    }

    public override func exportAsUIModel() -> UIMessageModelProtocol {
        let status = self.state.exportAsMessageStatus()

        do {
            let mediaStorage = try CoreData.shared.getMediaStorage()

            let audioUrl = try mediaStorage.getURL(name: self.identifier, type: .voice)
            let state: MediaMessageState = mediaStorage.exists(path: audioUrl.path) ? .normal : .downloading

            let uiModel = UIAudioMessageModel(uid: self.xmppId,
                                              audioUrl: audioUrl,
                                              duration: TimeInterval(self.duration),
                                              isIncoming: self.isIncoming,
                                              status: status,
                                              state: state,
                                              date: self.date)
            if state == .downloading {
                try Virgil.shared.client.startDownload(from: self.url,
                                                       loadDelegate: uiModel,
                                                       dataHash: self.identifier)
                { tempFileUrl in
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
        }
        catch {
            Log.error(error, message: "Exporting AudioMessage to UI model failed")

            return UITextMessageModel.corruptedModel(uid: self.xmppId,
                                                     isIncoming: self.isIncoming,
                                                     date: self.date)
        }    }
}
