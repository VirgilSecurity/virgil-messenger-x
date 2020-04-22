//
//  Storage+MessageUI.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 02.04.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import Chatto
import ChattoAdditions

public protocol UIMessageModelProtocol: MessageModelProtocol {
    var status: MessageStatus { get set }
}

extension Storage {
    public static func exportAsUIModel(message: Message) -> UIMessageModelProtocol {

        switch message {
        case let textMessage as TextMessage:
            return Self.exportAsUIModel(message: textMessage)

        case let photoMessage as PhotoMessage:
            return Self.exportAsUIModel(message: photoMessage)

        case let voiceMessage as VoiceMessage:
            return Self.exportAsUIModel(message: voiceMessage)

        case let callMessage as CallMessage:
            return Self.exportAsUIModel(message: callMessage)

        default:
            Log.error(Storage.Error.exportBaseMessageForbidden,
                      message: "Exporting abstract Message to UI model is forbidden")

            return UITextMessageModel.corruptedModel(uid: message.xmppId,
                                                     isIncoming: message.isIncoming,
                                                     date: message.date)
        }

    }

    public static func exportAsUIModel(message: TextMessage) -> UIMessageModelProtocol {
        let status = message.state.exportAsMessageStatus()

        return UITextMessageModel(uid: message.xmppId,
                                  text: message.body,
                                  isIncoming: message.isIncoming,
                                  status: status,
                                  date: message.date)
    }

    public static func exportAsUIModel(message: PhotoMessage) -> UIMessageModelProtocol {
        let status = message.state.exportAsMessageStatus()

        do {
            let path = try Storage.shared.getMediaStorage().getPath(name: message.identifier, type: .photo)

            let image: UIImage
            let state: MediaMessageState

            if let fullImage = UIImage(contentsOfFile: path) {
                image = fullImage
                state = .normal
            }
            else {
                image = try message.thumbnailImage()
                state = .downloading
            }

            let uiModel = UIPhotoMessageModel(uid: message.xmppId,
                                              image: image,
                                              isIncoming: message.isIncoming,
                                              status: status,
                                              state: state,
                                              date: message.date)

            if state == .downloading {
                try Virgil.shared.client.startDownload(from: message.url,
                                                       loadDelegate: uiModel,
                                                       dataHash: message.identifier)
                { tempFileUrl in
                    guard let inputStream = InputStream(url: tempFileUrl) else {
                        throw Client.Error.inputStreamFromDownloadedFailed
                    }

                    guard let outputStream = OutputStream(toFileAtPath: path, append: false) else {
                        throw FileMediaStorage.Error.outputStreamToPathFailed
                    }

                    // TODO: add self card usecase
                    try Virgil.ethree.authDecrypt(inputStream, to: outputStream, from: message.channel.getCard())
                }
            }

            return uiModel
        }
        catch {
            Log.error(error, message: "Exporting PhotoMessage to UI model failed")

            return UITextMessageModel.corruptedModel(uid: message.xmppId,
                                                     isIncoming: message.isIncoming,
                                                     date: message.date)
        }
    }

    public static func exportAsUIModel(message: VoiceMessage) -> UIMessageModelProtocol {
        let status = message.state.exportAsMessageStatus()

        do {
            let mediaStorage = try Storage.shared.getMediaStorage()

            let audioUrl = try mediaStorage.getURL(name: message.identifier, type: .voice)
            let state: MediaMessageState = mediaStorage.exists(path: audioUrl.path) ? .normal : .downloading

            let uiModel = UIAudioMessageModel(uid: message.xmppId,
                                              audioUrl: audioUrl,
                                              duration: TimeInterval(message.duration),
                                              isIncoming: message.isIncoming,
                                              status: status,
                                              state: state,
                                              date: message.date)
            if state == .downloading {
                try Virgil.shared.client.startDownload(from: message.url,
                                                       loadDelegate: uiModel,
                                                       dataHash: message.identifier)
                { tempFileUrl in
                    guard let inputStream = InputStream(url: tempFileUrl) else {
                        throw Client.Error.inputStreamFromDownloadedFailed
                    }

                    guard let outputStream = OutputStream(toFileAtPath: audioUrl.path, append: false) else {
                        throw FileMediaStorage.Error.outputStreamToPathFailed
                    }

                    // TODO: add self card usecase
                    try Virgil.ethree.authDecrypt(inputStream, to: outputStream, from: message.channel.getCard())
                }
            }

            return uiModel
        }
        catch {
            Log.error(error, message: "Exporting AudioMessage to UI model failed")

            return UITextMessageModel.corruptedModel(uid: message.xmppId,
                                                     isIncoming: message.isIncoming,
                                                     date: message.date)
        }
    }

    public static func exportAsUIModel(message: CallMessage) -> UIMessageModelProtocol {

        let text = message.isIncoming ? "Incomming call" : "Outgoing call"

        let status = message.state.exportAsMessageStatus()

        return UITextMessageModel(uid: message.xmppId,
                                  text: text,
                                  isIncoming: message.isIncoming,
                                  status: status,
                                  date: message.date)
    }
}
