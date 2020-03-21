import Chatto
import ChattoAdditions
import VirgilSDK

// TODO: Move to proper file
public protocol UIMessageModelExportable {
    func exportAsUIModel(withId id: Int, status: MessageStatus) -> UIMessageModelProtocol
}

public protocol UIMessageModelProtocol: MessageModelProtocol {
    var status: MessageStatus { get set }
}

// TODO: Get rid of ui models from this class
public class MessageSender {
    private let queue = DispatchQueue(label: "MessageSender")
    
    private func encryptThenSend(message: Message, date: Date, channel: Storage.Channel) throws {
        let exported = try message.exportAsJsonData()

        let ciphertext = try Virgil.ethree.authEncrypt(data: exported, for: channel.getCard())

        let encryptedMessage = EncryptedMessage(ciphertext: ciphertext, date: date)

        try Ejabberd.shared.send(encryptedMessage, to: channel.name)
    }

    public func send(text: Message.Text, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        do {
            try self.encryptThenSend(message: Message.text(text), date: date, channel: channel)

            _ = try Storage.shared.createTextMessage(text.body, in: channel, isIncoming: false, date: date)

            completion(nil)
        } catch {
            completion(error)
        }
    }

    public func send(callOffer: Message.CallOffer, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                try self.encryptThenSend(message: Message.callOffer(callOffer), date: date, channel: channel)

                let storageMessage = try Storage.shared.createCallMessage(in: channel, isIncoming: false, date: date)

                Notifications.post(message: storageMessage)

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    public func send(callAnswer: Message.CallAnswer, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                try self.encryptThenSend(message: Message.callAnswer(callAnswer), date: date, channel: channel)

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    public func send(iceCandidate: Message.IceCandidate, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                try self.encryptThenSend(message: Message.iceCandidate(iceCandidate), date: date, channel: channel)

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
    
    private func upload(data: Data, identifier: String, channel: Channel, loadDelegate: LoadDelegate) throws -> URL {
        // encrypt data
        let encryptedData = try Virgil.ethree.authEncrypt(data: data, for: channel.getCard())
        
        // request ejabberd slot
        let slot = try Ejabberd.shared.requestMediaSlot(name: identifier, size: encryptedData.count)
            .startSync()
            .get()
        
        // upload data
        try Virgil.shared.client.upload(data: encryptedData,
                                        with: slot.putRequest,
                                        loadDelegate: loadDelegate,
                                        dataHash: identifier)
            .startSync()
            .get()
        
        return slot.getURL
    }
    
    public func send(uiModel: UIAudioMessageModel, channel: Channel) {
        self.queue.async {
            do {
                // TODO: optimize. Do not fetch data to memrory, use streams
                let data = try Data(contentsOf: uiModel.audioUrl)
                
                let getUrl = try self.upload(data: data,
                                             identifier: uiModel.identifier,
                                             channel: channel,
                                             loadDelegate: uiModel)
                
                let voiceContent = VoiceContent(identifier: uiModel.identifier,
                                                duration: uiModel.duration,
                                                url: getUrl)
                let content = MessageContent.voice(voiceContent)
                
                try self.send(content: content, additionalData: nil, to: channel, date: uiModel.date)
                
                _ = try CoreData.shared.createVoiceMessage(with: voiceContent,
                                                           in: channel,
                                                           isIncoming: false)
                
                self.updateMessage(uiModel, status: .success)
            }
            catch {
                self.updateMessage(uiModel, status: .failed)
                Log.error(error, message: "Sending voice message failed")
            }
        }
    }
    
    public func send(uiModel: UIPhotoMessageModel, channel: Channel) {
        self.queue.async {
            do {
                guard let imageData = uiModel.image.jpegData(compressionQuality: 0.0),
                    let thumbnail = uiModel.image.resized(to: 10)?.jpegData(compressionQuality: 1.0) else {
                        throw UserFriendlyError.imageCompressionFailed
                }
        
                let hashString = Virgil.shared.crypto.computeHash(for: imageData)
                    .subdata(in: 0..<32)
                    .hexEncodedString()
            
                // Save it to File Storage
                try CoreData.shared.storeMediaContent(imageData, name: hashString, type: .photo)
                
                let getUrl = try self.upload(data: imageData,
                                             identifier: hashString,
                                             channel: channel,
                                             loadDelegate: uiModel)
                
                // encrypt message to ejabberd user
                let photoContent = PhotoContent(identifier: hashString, url: getUrl)
                let content = MessageContent.photo(photoContent)
                
                try self.send(content: content, additionalData: thumbnail, to: channel, date: uiModel.date)
                
                // Save local Core Data entity
                _ = try CoreData.shared.createPhotoMessage(with: photoContent,
                                                           thumbnail: thumbnail,
                                                           in: channel,
                                                           isIncoming: false)
                
                self.updateMessage(uiModel, status: .success)
            }
            catch {
                self.updateMessage(uiModel, status: .failed)
                Log.error(error, message: "Sending photo message failed")
            }
        }
    }

    public func send(uiModel: UITextMessageModel, channel: Channel) {
        self.queue.async {
            do {
                let textContent = TextContent(body: uiModel.body)
                let messageContent = MessageContent.text(textContent)
                
                try self.send(content: messageContent, additionalData: nil, to: channel, date: uiModel.date)

                _ = try CoreData.shared.createTextMessage(with: textContent,
                                                          in: channel,
                                                          isIncoming: uiModel.isIncoming,
                                                          date: uiModel.date)

                self.updateMessage(uiModel, status: .success)
            }
            catch {
                self.updateMessage(uiModel, status: .failed)
                Log.error(error, message: "Sending text message failed")
            }
        }
    }

    private func updateMessage(_ message: UIMessageModelProtocol, status: MessageStatus) {
        if message.status != status {
            message.status = status
        }
    }
}
