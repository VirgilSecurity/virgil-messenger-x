import Chatto
import ChattoAdditions
import VirgilSDK

public protocol UIMessageModelProtocol: MessageModelProtocol {
    var status: MessageStatus { get set }
}

public class MessageSender {
    public var onMessageChanged: ((_ message: UIMessageModelProtocol) -> Void)?

    private let queue = DispatchQueue(label: "MessageSender")
    
    func sendVoiceCallIceMessage(_ iceCandidate: CallIceCandidate, channel: Channel) throws {
        let messageContent = MessageContent.iceCandidate(iceCandidate)
        let plaintext = try messageContent.exportAsJsonString()
        
        try self.encryptThenSend(plaintext: plaintext, to: channel, with: Date())
    }
    
    func sendVoiceCallSessionDescription(_ sessionDescription: CallSessionDescription, channel: Channel) throws {
        let messageContent = MessageContent.sdp(sessionDescription)
        let plaintext = try messageContent.exportAsJsonString()
        
        try self.encryptThenSend(plaintext: plaintext, to: channel, with: Date())
    }

    public func send(uiModel: UITextMessageModel, coreChannel: Channel) throws {
        self.queue.async {
            do {
                let textContent = TextContent(body: uiModel.body)
                let messageContent = MessageContent.text(textContent)
                let plaintext = try messageContent.exportAsJsonString()

                try self.encryptThenSend(plaintext: plaintext, to: coreChannel, with: uiModel.date)
                
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
    
    private func encryptThenSend(plaintext: String, to channel: Channel, with date: Date) throws {
        let ciphertext = try Virgil.ethree.authEncrypt(text: plaintext, for: channel.getCard())
        
        let encryptedMessage = EncryptedMessage(ciphertext: ciphertext, date: date)

        try Ejabberd.shared.send(encryptedMessage, to: channel.name)
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
