import Chatto
import ChattoAdditions
import VirgilSDK
import VirgilE3Kit

// FIXME: Move to proper file
public protocol UIMessageModelExportable {
    func exportAsUIModel(withId id: Int, status: MessageStatus) -> UIMessageModelProtocol
}

public protocol UIMessageModelProtocol: MessageModelProtocol {
    var status: MessageStatus { get set }
}

public class MessageSender {
    private let queue = DispatchQueue(label: "MessageSender")

    private func send(message: Message, additionalData: Data?, to channel: Storage.Channel, date: Date) throws {
        let card = try channel.getCard()

        let ratchetChannel: RatchetChannel?
        if channel.type == .singleRatchet {
            ratchetChannel = try Virgil.ethree.getRatchetChannel(with: card)
        } else {
            ratchetChannel = nil
        }

        let exported = try message.exportAsJsonData()

        let ciphertext = try self.encrypt(data: exported, for: card, withRacthetChannel: ratchetChannel)

        var additionalData = additionalData

        if let data = additionalData {
            additionalData = try self.encrypt(data: data, for: card, withRacthetChannel: ratchetChannel)
        }

        let encryptedMessage = EncryptedMessage(ciphertext: ciphertext, date: date, additionalData: additionalData)

        try Ejabberd.shared.send(encryptedMessage, to: channel.name)
    }

    private func sendService(message: Message, additionalData: Data?, to channel: Storage.Channel, date: Date) throws {
        let card = try channel.getCard()

        let exported = try message.exportAsJsonData()

        let ciphertext = try self.encrypt(data: exported, for: card, withRacthetChannel: nil)

        let encryptedMessage = EncryptedMessage(ciphertext: ciphertext, date: date, additionalData: nil)

        try Ejabberd.shared.send(encryptedMessage, to: channel.name)
    }

    private func encrypt(data: Data, for card: Card, withRacthetChannel ratchetChannel: RatchetChannel?) throws -> Data {
        if let ratchetChannel = ratchetChannel {
            return try ratchetChannel.encrypt(data: data)
        }
        else {
            return try Virgil.ethree.authEncrypt(data: data, for: card)
        }
    }

    public func send(text: Message.Text, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        do {
            let message = Message.text(text)

            try self.send(message: message, additionalData: nil, to: channel, date: date)

            _ = try Storage.shared.createTextMessage(text, in: channel, isIncoming: false, date: date)

            completion(nil)
        } catch {
            completion(error)
        }
    }

    public func send(photo: Message.Photo, image: Data, thumbnail: Data, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        do {

            let message = Message.photo(photo)

            try self.send(message: message, additionalData: thumbnail, to: channel, date: date)

            try Storage.shared.storeMediaContent(image, name: photo.identifier, type: .photo)

            _ = try Storage.shared.createPhotoMessage(photo, thumbnail: thumbnail, in: channel, isIncoming: false)

            completion(nil)
        } catch {
            completion(error)
        }
    }

    public func send(voice: Message.Voice, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        do {

            let message = Message.voice(voice)

            try self.send(message: message, additionalData: nil, to: channel, date: date)

            _ = try Storage.shared.createVoiceMessage(voice, in: channel, isIncoming: false)

            completion(nil)
        } catch {
            completion(error)
        }
    }

    public func send(callOffer: Message.CallOffer, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                let message = Message.callOffer(callOffer)

                try self.send(message: message, additionalData: nil, to: channel, date: date)

                let storageMessage = try Storage.shared.createCallMessage(in: channel, isIncoming: false, date: date)

                Notifications.post(message: storageMessage)

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    public func send(callAcceptedAnswer: Message.CallAcceptedAnswer, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                let message = Message.callAcceptedAnswer(callAcceptedAnswer)

                try self.send(message: message, additionalData: nil, to: channel, date: date)

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    public func send(callRejectedAnswer: Message.CallRejectedAnswer, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                let message = Message.callRejectedAnswer(callRejectedAnswer)

                try self.send(message: message, additionalData: nil, to: channel, date: date)

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    public func send(iceCandidate: Message.IceCandidate, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                let message = Message.iceCandidate(iceCandidate)

                try self.send(message: message, additionalData: nil, to: channel, date: date)

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    public func upload(data: Data, identifier: String, channel: Storage.Channel, loadDelegate: LoadDelegate, completion: @escaping (URL?, Error?) -> Void) {
        self.queue.async {
            do {
                // encrypt data
                let encryptedData = try Virgil.ethree.authEncrypt(data: data, for: channel.getCard())

                // request ejabberd slot
                let slot = try Ejabberd.shared.requestMediaSlot(name: identifier, size: encryptedData.count)
                    .startSync()
                    .get()

                // upload data
                try Virgil.shared.client.upload(data: encryptedData, with: slot.putRequest, loadDelegate: loadDelegate, dataHash: identifier)
                    .startSync()
                    .get()

                completion(slot.getURL, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    public func send(newChannel: Message.NewChannel, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                let message = Message.newChannel(newChannel)

                try self.sendService(message: message, additionalData: nil, to: channel, date: date)

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
}
