import Chatto
import ChattoAdditions
import VirgilSDK

// FIXME: Move to proper file
public protocol UIMessageModelExportable {
    func exportAsUIModel(withId id: Int, status: MessageStatus) -> UIMessageModelProtocol
}

public protocol UIMessageModelProtocol: MessageModelProtocol {
    var status: MessageStatus { get set }
}

// TODO: Get rid of ui models from this class
public class MessageSender {
    public var onMessageChanged: ((_ message: UIMessageModelProtocol) -> Void)?

    private let queue = DispatchQueue(label: "MessageSender")
    
    private func send(content: MessageContent, to channel: Channel, date: Date) throws {
        let exported = try content.exportAsJsonString()

        let ciphertext = try Virgil.ethree.authEncrypt(data: exported, for: channel.getCard())

        let encryptedMessage = EncryptedMessage(ciphertext: ciphertext, date: date)

        try Ejabberd.shared.send(encryptedMessage, to: channel.name)
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
    
    public func send(uiModel: UIAudioMessageModel, channel: Channel) throws {
        self.queue.async {
            do {
                // FIXME: optimize. Do not fetch data to memrory, use streams
                let data = try Data(contentsOf: uiModel.audioUrl)
                
                let getUrl = try self.upload(data: data,
                                             identifier: uiModel.identifier,
                                             channel: channel,
                                             loadDelegate: uiModel)
                
                // FIXME duration type
                let voiceContent = VoiceContent(identifier: uiModel.identifier,
                                                duration: Int(uiModel.duration),
                                                url: getUrl)
                let content = MessageContent.voice(voiceContent)
                
                try self.send(content: content, to: channel, date: uiModel.date)
                
                _ = try CoreData.shared.createVoiceMessage(with: voiceContent,
                                                           in: channel,
                                                           isIncoming: false)
                
                self.updateMessage(uiModel, status: .success)
            }
            catch {
                self.updateMessage(uiModel, status: .failed)
                Log.error("Sending message failed with error: \(error.localizedDescription)")
            }
        }
    }
    
    public func send(uiModel: UIPhotoMessageModel, channel: Channel) throws {
        self.queue.async {
            do {
                // FIXME: Compression quality
                guard let imageData = uiModel.image.jpegData(compressionQuality: 0.0),
                    let thumbnail = uiModel.image.resized(to: 10)?.jpegData(compressionQuality: 1.0) else {
                        throw NSError()
                }
        
                // FIXME: check why string
                // FIXME: 64 bytes length is too much
                let hashString = Virgil.shared.crypto.computeHash(for: imageData)
                    .subdata(in: 0..<32)
                    .hexEncodedString()
            
                // Save it to File Storage
                // FIXME: Check if exists
                try CoreData.shared.storeMediaContent(imageData, name: hashString)
                
                let getUrl = try self.upload(data: imageData,
                                             identifier: hashString,
                                             channel: channel,
                                             loadDelegate: uiModel)
                
                // encrypt message to ejabberd user
                let photoContent = PhotoContent(identifier: hashString, thumbnail: thumbnail, url: getUrl)
                let content = MessageContent.photo(photoContent)
                
                try self.send(content: content, to: channel, date: uiModel.date)
                
                // Save local Core Data entity
                _ = try CoreData.shared.createPhotoMessage(with: photoContent,
                                                           in: channel,
                                                           isIncoming: false)
                
                self.updateMessage(uiModel, status: .success)
            }
            catch {
                self.updateMessage(uiModel, status: .failed)
                Log.error("Sending message failed with error: \(error.localizedDescription)")
            }
        }
    }

    public func send(uiModel: UITextMessageModel, channel: Channel) throws {
        self.queue.async {
            do {
                let textContent = TextContent(body: uiModel.body)
                let messageContent = MessageContent.text(textContent)
                
                try self.send(content: messageContent, to: channel, date: uiModel.date)

                _ = try CoreData.shared.createTextMessage(with: textContent,
                                                          in: channel,
                                                          isIncoming: uiModel.isIncoming,
                                                          date: uiModel.date)

                self.updateMessage(uiModel, status: .success)
            }
            catch {
                self.updateMessage(uiModel, status: .failed)
                Log.error("Sending message failed with error: \(error.localizedDescription)")
            }
        }
    }

    private func updateMessage(_ message: UIMessageModelProtocol, status: MessageStatus) {
        if message.status != status {
            message.status = status
            self.notifyMessageChanged(message)
        }
    }

    private func notifyMessageChanged(_ message: UIMessageModelProtocol) {
        DispatchQueue.main.async {
            self.onMessageChanged?(message)
        }
    }
}
