import Chatto
import ChattoAdditions
import VirgilSDK

public class MessageSender {
    private let queue = DispatchQueue(label: "MessageSender")

    // Returns xmppId
    private func send(message: NetworkMessage, pushType: PushType, additionalData: Data?, to channel: Storage.Channel, date: Date, xmppId: String? = nil) throws -> String {
        let exported = try message.exportAsJsonData()

        let card = try channel.getCard()
        let ciphertext = try Virgil.ethree.authEncrypt(data: exported, for: card)

        var additionalData = additionalData

        if let data = additionalData {
            additionalData = try Virgil.ethree.authEncrypt(data: data, for: card)
        }

        let encryptedMessage = EncryptedMessage(pushType: pushType, ciphertext: ciphertext, date: date, additionalData: additionalData)

        return try Ejabberd.shared.send(encryptedMessage, to: channel.name, xmppId: xmppId)
    }

    public func send(text: NetworkMessage.Text, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        do {
            let message = NetworkMessage.text(text)

            let xmppId = try self.send(message: message, pushType: .alert, additionalData: nil, to: channel, date: date)

            _ = try Storage.shared.createTextMessage(text, xmppId: xmppId, in: channel, isIncoming: false, date: date)

            completion(nil)
        } catch {
            completion(error)
        }
    }

    public func send(photo: NetworkMessage.Photo, image: Data, thumbnail: Data, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        do {

            let message = NetworkMessage.photo(photo)

            let xmppId = try self.send(message: message, pushType: .alert, additionalData: thumbnail, to: channel, date: date)

            try Storage.shared.storeMediaContent(image, name: photo.identifier, type: .photo)

            _ = try Storage.shared.createPhotoMessage(photo, thumbnail: thumbnail, xmppId: xmppId, in: channel, isIncoming: false)

            completion(nil)
        } catch {
            completion(error)
        }
    }

    public func send(voice: NetworkMessage.Voice, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        do {

            let message = NetworkMessage.voice(voice)

            let xmppId = try self.send(message: message, pushType: .alert, additionalData: nil, to: channel, date: date)

            _ = try Storage.shared.createVoiceMessage(voice, xmppId: xmppId, in: channel, isIncoming: false)

            completion(nil)
        } catch {
            completion(error)
        }
    }

    public func send(callOffer: NetworkMessage.CallOffer, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                let message = NetworkMessage.callOffer(callOffer)

                let xmppId = try self.send(message: message,
                                           pushType: .voip,
                                           additionalData: nil,
                                           to: channel,
                                           date: date,
                                           xmppId: callOffer.callUUID.uuidString)

                let storageMessage = try Storage.shared.createCallMessage(xmppId: xmppId, in: channel, isIncoming: false, date: date)

                Notifications.post(message: storageMessage)

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    public func send(callAnswer: NetworkMessage.CallAnswer, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                let message = NetworkMessage.callAnswer(callAnswer)

                _ = try self.send(message: message, pushType: .none, additionalData: nil, to: channel, date: date)

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    public func send(callUpdate: NetworkMessage.CallUpdate, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                let message = NetworkMessage.callUpdate(callUpdate)

                _ = try self.send(message: message, pushType: .none, additionalData: nil, to: channel, date: date)

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    public func send(iceCandidate: NetworkMessage.IceCandidate, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                let message = NetworkMessage.iceCandidate(iceCandidate)

                _ = try self.send(message: message, pushType: .none, additionalData: nil, to: channel, date: date)

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
}
