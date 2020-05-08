import Chatto
import ChattoAdditions
import VirgilSDK

public class MessageSender {
    private let queue = DispatchQueue(label: "MessageSender")

    private func send(message: NetworkMessage,
                      pushType: PushType,
                      additionalData: Data?,
                      to channel: Storage.Channel,
                      date: Date,
                      messageId: String) throws {

        let exported = try message.exportAsJsonData()

        let card = try channel.getCard()
        let ciphertext = try Virgil.ethree.authEncrypt(data: exported, for: card)

        var additionalData = additionalData

        if let data = additionalData {
            additionalData = try Virgil.ethree.authEncrypt(data: data, for: card)
        }

        let encryptedMessage = EncryptedMessage(pushType: pushType, ciphertext: ciphertext, date: date, additionalData: additionalData)

        try Ejabberd.shared.send(encryptedMessage, to: channel.name, xmppId: messageId)
    }

    public func send(text: NetworkMessage.Text,
                     date: Date,
                     channel: Storage.Channel,
                     messageId: String,
                     completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                let message = NetworkMessage.text(text)

                try self.send(message: message, pushType: .alert, additionalData: nil, to: channel, date: date, messageId: messageId)

                let baseParams = Storage.Message.Params(xmppId: messageId, isIncoming: false, channel: channel, state: .sent)

                try Storage.shared.createTextMessage(with: text, baseParams: baseParams)

                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }

    public func send(callOffer: NetworkMessage.CallOffer,
                     date: Date,
                     channel: Storage.Channel,
                     messageId: String,
                     completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                let message = NetworkMessage.callOffer(callOffer)

                try self.send(message: message, pushType: .voip, additionalData: nil, to: channel, date: date, messageId: messageId)

                let baseParams = Storage.Message.Params(xmppId: messageId, isIncoming: false, channel: channel, state: .sent)

                let storageMessage = try Storage.shared.createCallMessage(with: callOffer, baseParams: baseParams)

                Notifications.post(message: storageMessage)

                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }

    public func send(callAnswer: NetworkMessage.CallAnswer,
                     date: Date,
                     channel: Storage.Channel,
                     messageId: String,
                     completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                let message = NetworkMessage.callAnswer(callAnswer)

                try self.send(message: message, pushType: .none, additionalData: nil, to: channel, date: date, messageId: messageId)

                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }

    public func send(callUpdate: NetworkMessage.CallUpdate,
                     date: Date,
                     channel: Storage.Channel,
                     messageId: String,
                     completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                let message = NetworkMessage.callUpdate(callUpdate)

                try self.send(message: message, pushType: .none, additionalData: nil, to: channel, date: date, messageId: messageId)

                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }

    public func send(iceCandidate: NetworkMessage.IceCandidate,
                     date: Date,
                     channel: Storage.Channel,
                     messageId: String,
                     completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                let message = NetworkMessage.iceCandidate(iceCandidate)

                try self.send(message: message, pushType: .none, additionalData: nil, to: channel, date: date, messageId: messageId)

                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }

    public func uploadAndSend(image: UIImage,
                              date: Date,
                              channel: Storage.Channel,
                              messageId: String,
                              loadDelegate: LoadDelegate,
                              completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                guard
                    let imageData = image.jpegData(compressionQuality: 0.0),
                    let thumbnail = image.resized(to: 10)?.jpegData(compressionQuality: 1.0)
                else {
                    completion(UserFriendlyError.imageCompressionFailed)
                    return
                }

                let hashString = Virgil.shared.crypto.computeHash(for: imageData)
                    .subdata(in: 0..<32)
                    .hexEncodedString()

                try Storage.shared.storeMediaContent(imageData, name: hashString, type: .photo)

                let url = try self.upload(data: imageData, identifier: hashString, channel: channel, loadDelegate: loadDelegate)

                let photo = NetworkMessage.Photo(identifier: hashString, url: url)
                let message = NetworkMessage.photo(photo)

                try self.send(message: message, pushType: .alert, additionalData: thumbnail, to: channel, date: date, messageId: messageId)

                let baseParams = Storage.Message.Params(xmppId: messageId, isIncoming: false, channel: channel, state: .sent)
                try Storage.shared.createPhotoMessage(with: photo, thumbnail: thumbnail, baseParams: baseParams)

                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }

    public func uploadAndSend(voice voiceURL: URL,
                              identifier: String,
                              duration: TimeInterval,
                              date: Date,
                              channel: Storage.Channel,
                              messageId: String,
                              loadDelegate: LoadDelegate,
                              completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                // TODO: optimize. Do not fetch data to memory, use streams
                let voiceData: Data = try Data(contentsOf: voiceURL)
                let url = try self.upload(data: voiceData, identifier: identifier, channel: channel, loadDelegate: loadDelegate)
                let voice = NetworkMessage.Voice(identifier: identifier, duration: duration, url: url)

                let message = NetworkMessage.voice(voice)

                try self.send(message: message, pushType: .alert, additionalData: nil, to: channel, date: date, messageId: messageId)

                let baseParams = Storage.Message.Params(xmppId: messageId, isIncoming: false, channel: channel, state: .sent)
                try Storage.shared.createVoiceMessage(with: voice, baseParams: baseParams)

                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }

    private func upload(data: Data, identifier: String, channel: Storage.Channel, loadDelegate: LoadDelegate) throws -> URL {
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

        return slot.getURL
    }
}
