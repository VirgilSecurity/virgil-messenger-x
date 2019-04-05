//
//  Message.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/5/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit
import AVFoundation

extension Message {
    public func exportAsUIModel(withId id: Int) -> DemoMessageModelProtocol {
        let corruptedMessage = {
            MessageFactory.createTextMessageModel("\(id)",
                                                  text: "Corrupted Message",
                                                  isIncoming: self.isIncoming,
                                                  status: .failed,
                                                  date: Date())
        }

        guard let date = self.date,
            let type = self.type else {
                return corruptedMessage()
        }

        let resultMessage: DemoMessageModelProtocol

        switch type {
        case CoreDataHelper.MessageType.text.rawValue:
            guard let body = self.body else {
                return corruptedMessage()
            }

            resultMessage = MessageFactory.createTextMessageModel("\(id)",
                                                                  text: body,
                                                                  isIncoming: self.isIncoming,
                                                                  status: .success,
                                                                  date: date)
        case CoreDataHelper.MessageType.photo.rawValue:
            guard let media = self.media, let image = UIImage(data: media) else {
                return corruptedMessage()
            }

            resultMessage = MessageFactory.createPhotoMessageModel("\(id)",
                                                                   image: image,
                                                                   size: image.size,
                                                                   isIncoming: self.isIncoming,
                                                                   status: .success,
                                                                   date: date)
        case CoreDataHelper.MessageType.audio.rawValue:
            guard let media = self.media, let duration = try? AVAudioPlayer(data: media).duration else {
                return corruptedMessage()
            }

            resultMessage = MessageFactory.createAudioMessageModel("\(id)",
                                                                   audio: media,
                                                                   duration: duration,
                                                                   isIncoming: self.isIncoming,
                                                                   status: .success,
                                                                   date: date)
        default:
            return corruptedMessage()
        }

        return resultMessage
    }
}
