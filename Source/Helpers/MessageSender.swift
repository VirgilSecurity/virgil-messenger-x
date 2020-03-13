import Chatto
import ChattoAdditions
import VirgilSDK

public protocol UIMessageModelProtocol: MessageModelProtocol {
    var status: MessageStatus { get set }
}

public class MessageSender {
    public var onMessageChanged: ((_ message: UIMessageModelProtocol) -> Void)?

    private let queue = DispatchQueue(label: "MessageSender")

    public func send(messageContent: MessageContent, date: Date, channel: Channel, completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                let exported = try messageContent.exportAsJsonString()

                let ciphertext = try Virgil.ethree.authEncrypt(text: exported, for: channel.getCard())

                let encryptedMessage = EncryptedMessage(ciphertext: ciphertext, date: date)

                try Ejabberd.shared.send(encryptedMessage, to: channel.name)

//                _ = try CoreData.shared.createTextMessage(<#T##body: String##String#>, isIncoming: <#T##Bool#>)(uiModel.body,
//                                                          in: coreChannel,
//                                                          isIncoming: uiModel.isIncoming,
//                                                          date: uiModel.date)

                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }

    public func send(uiModel: UITextMessageModel, coreChannel: Channel) throws {
        self.queue.async {
            do {
                let textContent = MessageContent.Text(body: uiModel.body)
                let messageContent = MessageContent.text(textContent)
                let exported = try messageContent.exportAsJsonString()

                let ciphertext = try Virgil.ethree.authEncrypt(text: exported, for: coreChannel.getCard())

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
