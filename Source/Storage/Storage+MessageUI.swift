//
//  Storage+MessageUI.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 02.04.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import ChattoAdditions

public protocol UIMessageModelProtocol: MessageModelProtocol {
    var status: MessageStatus { get set }
}

extension Storage {
    public static func exportAsUIModel(message: Storage.Message, with uid: Int, status: MessageStatus = .success) -> UIMessageModelProtocol {

        switch message {
        case let textMessage as Storage.TextMessage:
            return Self.exportAsUIModel(message: textMessage, with: uid)

        case let photoMessage as Storage.PhotoMessage:
            return Self.exportAsUIModel(message: photoMessage, with: uid)

        case let voiceMessage as Storage.VoiceMessage:
            return Self.exportAsUIModel(message: voiceMessage, with: uid)

        case let callMessage as Storage.CallMessage:
            return Self.exportAsUIModel(message: callMessage, with: uid)

        default:
            Log.error(Storage.Error.exportBaseMessageForbidden,
                      message: "Exporting abstract Message to UI model is forbidden")

            return UITextMessageModel.corruptedModel(uid: uid,
                                                     isIncoming: message.isIncoming,
                                                     date: message.date)
        }

    }

    public static func exportAsUIModel(message: Storage.TextMessage, with uid: Int, status: MessageStatus = .success) -> UIMessageModelProtocol {
        return UITextMessageModel(uid: uid,
                                  text: message.body,
                                  isIncoming: message.isIncoming,
                                  status: status,
                                  date: message.date)
    }

    public static func exportAsUIModel(message: Storage.PhotoMessage, with uid: Int, status: MessageStatus = .success) -> UIMessageModelProtocol {
        do {
            let path = try Storage.shared.getMediaStorage().getPath(name: message.identifier, type: .photo)

            let image: UIImage
            let state: MediaMessageState

            if let fullImage = UIImage(contentsOfFile: path) {
                image = fullImage
                state = .normal
            } else {
                image = try message.thumbnailImage()
                state = .downloading
            }

           let uiModel = UIPhotoMessageModel(uid: uid,
                                             image: image,
                                             isIncoming: message.isIncoming,
                                             status: status,
                                             state: state,
                                             date: message.date)

            if state == .downloading {
                try Virgil.shared.client.startDownload(from: message.url,
                                                       loadDelegate: uiModel,
                                                       dataHash: message.identifier) { tempFileUrl in
                    guard let inputStream = InputStream(url: tempFileUrl) else {
                        throw Client.Error.inputStreamFromDownloadedFailed
                    }

                    guard let outputStream = OutputStream(toFileAtPath: path, append: false) else {
                        throw FileMediaStorage.Error.outputStreamToPathFailed
                    }

                    // TODO: add message card usecase
                    try Virgil.ethree.authDecrypt(inputStream, to: outputStream, from: message.channel.getCard())
                }
            }

            return uiModel
        } catch {
            Log.error(error, message: "Exporting PhotoMessage to UI model failed")

            return UITextMessageModel.corruptedModel(uid: uid,
                                                     isIncoming: message.isIncoming,
                                                     date: message.date)
        }
    }

    public static func exportAsUIModel(message: Storage.VoiceMessage, with uid: Int, status: MessageStatus = .success) -> UIMessageModelProtocol {
        do {
            let mediaStorage = try Storage.shared.getMediaStorage()

            let audioUrl = try mediaStorage.getURL(name: message.identifier, type: .voice)
            let state: MediaMessageState = mediaStorage.exists(path: audioUrl.path) ? .normal : .downloading

            let uiModel = UIAudioMessageModel(uid: uid,
                                              audioUrl: audioUrl,
                                              duration: TimeInterval(message.duration),
                                              isIncoming: message.isIncoming,
                                              status: status,
                                              state: state,
                                              date: message.date)
            if state == .downloading {
                try Virgil.shared.client.startDownload(from: message.url,
                                                       loadDelegate: uiModel,
                                                       dataHash: message.identifier) { tempFileUrl in
                    guard let inputStream = InputStream(url: tempFileUrl) else {
                        throw Client.Error.inputStreamFromDownloadedFailed
                    }

                    guard let outputStream = OutputStream(toFileAtPath: audioUrl.path, append: false) else {
                        throw FileMediaStorage.Error.outputStreamToPathFailed
                    }

                    // TODO: add message card usecase
                    try Virgil.ethree.authDecrypt(inputStream, to: outputStream, from: message.channel.getCard())
                }
            }

            return uiModel
        } catch {
            Log.error(error, message: "Exporting AudioMessage to UI model failed")

            return UITextMessageModel.corruptedModel(uid: uid,
                                                     isIncoming: message.isIncoming,
                                                     date: message.date)
        }
    }

    public static func exportAsUIModel(message: Storage.CallMessage, with uid: Int, status: MessageStatus = .success) -> UIMessageModelProtocol {
        let text = message.isIncoming ? "Incomming call from \(message.channelName)" : "Outgoing call to \(message.channelName)"

        return UITextMessageModel(uid: uid,
                                  text: text,
                                  isIncoming: message.isIncoming,
                                  status: status,
                                  date: message.date)
    }
}
