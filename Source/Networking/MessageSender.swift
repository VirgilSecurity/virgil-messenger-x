import Chatto
import ChattoAdditions
import VirgilSDK
import VirgilCryptoFoundation
import VirgilCryptoRatchet

public class MessageSender {
    public enum Error: Swift.Error {
        case ratchetChannelNotFound
    }

    // TODO: Think of using global concurrent queue
    private let queue = DispatchQueue(label: "MessageSender", qos: .userInitiated)

    private func send(message: NetworkMessage,
                      pushType: PushType,
                      thumbnail: Data?,
                      to channel: Storage.Channel,
                      date: Date,
                      messageId: String) throws {

        let exported = try message.exportAsJsonData()

        let card = try channel.getCard()
        
        guard let ratchetChannel = try Virgil.ethree.getRatchetChannel(with: card) else {
            throw Error.ratchetChannelNotFound
        }
        
        var additionalData = AdditionalData()
        
        let ratchetCipherText = try ratchetChannel.encrypt(data: exported)
        var ciphertext: Data?
        
        // TODO: Optimize. E3Kit doesn't return message, only its serialized version
        let message = try! RatchetMessage.deserialize(input: ratchetCipherText)
        if message.getType() == .prekey {
            // Send empty push message
            additionalData.prekeyMessage = ratchetCipherText
            ciphertext = nil
        }
        else {
            ciphertext = ratchetCipherText
        }

        if let thumbnail = thumbnail {
            additionalData.thumbnail = try ratchetChannel.encrypt(data: thumbnail)
        }

        let encryptedMessage = EncryptedMessage(pushType: pushType, ciphertext: ciphertext, date: date, additionalData: additionalData)

        try Ejabberd.shared.send(encryptedMessage, to: channel.name, xmppId: messageId)
    }

    public func send(text: NetworkMessage.Text,
                     date: Date,
                     channel: Storage.Channel,
                     messageId: String,
                     completion: @escaping (Swift.Error?) -> Void) {
        self.queue.async {
            do {
                let message = NetworkMessage.text(text)

                try self.send(message: message, pushType: .alert, thumbnail: nil, to: channel, date: date, messageId: messageId)

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
                     completion: @escaping (Swift.Error?) -> Void) {
        self.queue.async {
            do {
                let message = NetworkMessage.callOffer(callOffer)

                try self.send(message: message, pushType: .voip, thumbnail: nil, to: channel, date: date, messageId: messageId)

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
                     completion: @escaping (Swift.Error?) -> Void) {
        self.queue.async {
            do {
                let message = NetworkMessage.callAnswer(callAnswer)

                try self.send(message: message, pushType: .none, thumbnail: nil, to: channel, date: date, messageId: messageId)

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
                     completion: @escaping (Swift.Error?) -> Void) {
        self.queue.async {
            do {
                let message = NetworkMessage.callUpdate(callUpdate)

                try self.send(message: message, pushType: .none, thumbnail: nil, to: channel, date: date, messageId: messageId)

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
                     completion: @escaping (Swift.Error?) -> Void) {
        self.queue.async {
            do {
                let message = NetworkMessage.iceCandidate(iceCandidate)

                try self.send(message: message, pushType: .none, thumbnail: nil, to: channel, date: date, messageId: messageId)

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
                              completion: @escaping (Swift.Error?) -> Void) {
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

                let uploadResult = try self.upload(data: imageData, identifier: hashString, channel: channel, loadDelegate: loadDelegate)

                let photo = NetworkMessage.Photo(identifier: hashString, url: uploadResult.url, secret: uploadResult.secret)
                let message = NetworkMessage.photo(photo)

                try self.send(message: message, pushType: .alert, thumbnail: thumbnail, to: channel, date: date, messageId: messageId)

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
                              completion: @escaping (Swift.Error?) -> Void) {
        self.queue.async {
            do {
                // TODO: optimize. Do not fetch data to memory, use streams
                let voiceData: Data = try Data(contentsOf: voiceURL)
                let uploadResult = try self.upload(data: voiceData, identifier: identifier, channel: channel, loadDelegate: loadDelegate)
                let voice = NetworkMessage.Voice(identifier: identifier, duration: duration, url: uploadResult.url, secret: uploadResult.secret)

                let message = NetworkMessage.voice(voice)

                try self.send(message: message, pushType: .alert, thumbnail: nil, to: channel, date: date, messageId: messageId)

                let baseParams = Storage.Message.Params(xmppId: messageId, isIncoming: false, channel: channel, state: .sent)
                try Storage.shared.createVoiceMessage(with: voice, baseParams: baseParams)

                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }
    
    struct UploadResult {
        let url: URL
        let secret: Data
    }

    private func upload(data: Data, identifier: String, channel: Storage.Channel, loadDelegate: LoadDelegate) throws -> UploadResult {
        let result = try Virgil.symmetricEncrypt(data: data)

        // request ejabberd slot
        let slot = try Ejabberd.shared.requestMediaSlot(name: identifier, size: result.encryptedData.count)
            .startSync()
            .get()

        // upload data
        try Virgil.shared.client.upload(data: result.encryptedData, with: slot.putRequest, loadDelegate: loadDelegate, dataHash: identifier)
            .startSync()
            .get()

        return UploadResult(url: slot.getURL, secret: result.secret)
    }
}
