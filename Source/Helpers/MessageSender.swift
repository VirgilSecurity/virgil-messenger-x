import Chatto
import ChattoAdditions
import VirgilSDK

public protocol UIMessageModelProtocol: MessageModelProtocol {
    var status: MessageStatus { get set }
}

public class MessageSender {
    public var onMessageChanged: ((_ message: UIMessageModelProtocol) -> Void)?

    private let queue = DispatchQueue(label: "MessageSender")
    
    public func send(uiModel: UIPhotoMessageModel, coreChannel: Channel) throws {
        self.queue.async {
            do {
                // FIXME: Compression quality
                guard let data = uiModel.image.jpegData(compressionQuality: 0.0) else {
                    throw NSError()
                }
        
                let hash = Virgil.shared.crypto.computeHash(for: data)
                let hashString = hash.hexEncodedString()
            
                // Save it to File Storage
                // TODO: Check if exists
                try CoreData.shared.storeMediaContent(data, name: hashString)
                
                // encrypt image
                let encryptedData = try Virgil.ethree.authEncrypt(data: data, for: coreChannel.getCard())
                
                // request ejabberd slot
                let slot = try Ejabberd.shared.requestMediaSlot(name: hashString, size: encryptedData.count)
                    .startSync()
                    .get()
                
                // upload image
                try Virgil.shared.client.upload(data: encryptedData, with: slot.putRequest)
                
                // encrypt message to ejabberd user
                let messageContent = MessageContent(type: .photo, mediaHash: hashString, mediaUrl: slot.getURL)
                let exported = try messageContent.export()
                let ciphertext = try Virgil.ethree.authEncrypt(text: exported, for: coreChannel.getCard())
                let encryptedMessage = EncryptedMessage(ciphertext: ciphertext, date: uiModel.date)
                
                // send it
                try Ejabberd.shared.send(encryptedMessage, to: coreChannel.name)
                
                // Save local Core Data entity
                _ = try CoreData.shared.createMediaMessage(type: .photo,
                                                           in: coreChannel,
                                                           mediaHash: hashString,
                                                           mediaUrl: slot.getURL,
                                                           isIncoming: false)
                
                self.updateMessage(uiModel, status: .success)
            }
            catch {
                self.updateMessage(uiModel, status: .failed)
                Log.error("Sending message failed with error: \(error.localizedDescription)")
            }
        }
    }

    public func send(uiModel: UITextMessageModel, coreChannel: Channel) throws {
        self.queue.async {
            do {
                let messageContent = MessageContent(body: uiModel.body)
                let exportedContent = try messageContent.export()

                let ciphertext: String

                switch coreChannel.type {
                case .group:
                    let group = try coreChannel.getGroup()

                    ciphertext = try group.encrypt(text: exportedContent)
                case .single:
                    ciphertext = try Virgil.ethree.authEncrypt(text: exportedContent, for: coreChannel.getCard())
                }
                
                let encryptedMessage = EncryptedMessage(ciphertext: ciphertext, date: uiModel.date)

                try Ejabberd.shared.send(encryptedMessage, to: coreChannel.name)

                _ = try CoreData.shared.createTextMessage(uiModel.body,
                                                          in: coreChannel,
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
