import Chatto
import ChattoAdditions
import TwilioChatClient
import VirgilSDK

public protocol UIMessageModelProtocol: MessageModelProtocol {
    var status: MessageStatus { get set }
}

public class MessageSender {
    public var onMessageChanged: ((_ message: UIMessageModelProtocol) -> Void)?

    private let queue = DispatchQueue(label: "MessageSender")

    public func sendChangeMembers(message: String, coreChannel: Channel) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let twilioChannel = try Twilio.shared.getCurrentChannel()

                let group = try coreChannel.getGroup()

                let ciphertext = try group.encrypt(text: message)

                try twilioChannel.send(ciphertext: ciphertext, type: .service).startSync().get()

                _ = try CoreData.shared.createChangeMembersMessage(message, isIncoming: false)

                completion((), nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    public func send(uiModel: UITextMessageModel, coreChannel: Channel) throws {
        let twilioChannel = try Twilio.shared.getCurrentChannel()

        self.queue.async {
            do {
                let plaintext = uiModel.body

                let ciphertext: String

                switch coreChannel.type {
                case .group:
                    let group = try coreChannel.getGroup()

                    ciphertext = try group.encrypt(text: plaintext)
                case .single:
                    ciphertext = try Virgil.ethree.authEncrypt(text: plaintext, for: coreChannel.getCard())
                }

                try twilioChannel.send(ciphertext: ciphertext, type: .regular).startSync().get()

                _ = try CoreData.shared.createTextMessage(plaintext,
                                                          in: coreChannel,
                                                          isIncoming: uiModel.isIncoming,
                                                          date: uiModel.date)

                self.updateMessage(uiModel, status: .success)
            } catch {
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
