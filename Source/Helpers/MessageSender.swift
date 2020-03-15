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

public class MessageSender {
    public var onMessageChanged: ((_ message: UIMessageModelProtocol) -> Void)?

    private let queue = DispatchQueue(label: "MessageSender")
    
    // TODO: Get rid of ui models from this class
    public func send(uiModel: UIPhotoMessageModel, coreChannel: Channel) throws {
        self.queue.async {
            do {
                // FIXME: Compression quality
                guard let imageData = uiModel.image.jpegData(compressionQuality: 0.0),
                    let thumbnail = uiModel.image.resized(to: 10)?.jpegData(compressionQuality: 1.0) else {
                        throw NSError()
                }
        
                let hash = Virgil.shared.crypto.computeHash(for: imageData)
                // FIXME: check why string
                let hashString = hash.subdata(in: 0..<32).hexEncodedString()
            
                // Save it to File Storage
                // TODO: Check if exists
                try CoreData.shared.storeMediaContent(imageData, name: hashString)
                
                // encrypt image
                let encryptedData = try Virgil.ethree.authEncrypt(data: imageData, for: coreChannel.getCard())
                
                // request ejabberd slot
                let slot = try Ejabberd.shared.requestMediaSlot(name: hashString, size: encryptedData.count)
                    .startSync()
                    .get()
                
                // upload image
                try Virgil.shared.client.upload(data: encryptedData,
                                                with: slot.putRequest,
                                                loadDelegate: uiModel,
                                                dataHash: hashString)
                    .startSync()
                    .get()
                
                // encrypt message to ejabberd user
                let photoContent = PhotoContent(identifier: hashString, thumbnail: thumbnail, url: slot.getURL)
                let content = MessageContent.photo(photoContent)
                let exportedContent = try content.exportAsJsonString()
                
                let ciphertext = try Virgil.ethree.authEncrypt(text: exportedContent, for: coreChannel.getCard())
                let encryptedMessage = EncryptedMessage(ciphertext: ciphertext, date: uiModel.date)
                
                // send it
                try Ejabberd.shared.send(encryptedMessage, to: coreChannel.name)
                
                // Save local Core Data entity
                _ = try CoreData.shared.createPhotoMessage(with: photoContent,
                                                           in: coreChannel,
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
                let textContent = TextContent(body: uiModel.body)
                let messageContent = MessageContent.text(textContent)
                let exported = try messageContent.exportAsJsonString()

                let ciphertext = try Virgil.ethree.authEncrypt(text: exported, for: coreChannel.getCard())

                let encryptedMessage = EncryptedMessage(ciphertext: ciphertext, date: uiModel.date)

                try Ejabberd.shared.send(encryptedMessage, to: coreChannel.name)

                _ = try CoreData.shared.createTextMessage(with: textContent,
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
