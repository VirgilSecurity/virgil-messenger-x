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

    public func sendChangeMembers(message: Message) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let channel = try Twilio.shared.getCurrentChannel()

                let plaintext = try message.getBody()

                let group = try message.channel.getGroup()

                let ciphertext = try group.encrypt(text: plaintext)

                channel.send(ciphertext: ciphertext, type: .service).start(completion: completion)
            } catch {
                completion(nil, error)
            }
        }
    }

    public func send(message: Message, withId id: Int) throws -> UIMessageModelProtocol {
        let cards = message.channel.cards

        let channel = try Twilio.shared.currentChannel ?? Twilio.shared.getChannel(message.channel)

        let uiModel = message.exportAsUIModel(withId: id, status: .sending)

        self.queue.async {
            do {
                switch message.type {
                case .text:
                    let plaintext = try message.getBody()

                    let ciphertext: String
                    switch message.channel.type {
                    case .group:
                        let group = try message.channel.getGroup()

                        ciphertext = try group.encrypt(text: plaintext)
                    case .single:
                        ciphertext = try Virgil.ethree.authEncrypt(text: plaintext, for: cards.first!)
                    }

                    try channel.send(ciphertext: ciphertext, type: .regular).startSync().get()
                case .photo:
                    break
                case .audio:
                    break
                case .changeMembers:
                    let plaintext = try message.getBody()

                    let group = try message.channel.getGroup()

                    let ciphertext = try group.encrypt(text: plaintext)

                    try channel.send(ciphertext: ciphertext, type: .service).startSync().get()
                }

                self.updateMessage(uiModel, status: .success)
            } catch {
                self.updateMessage(uiModel, status: .failed)
            }
        }

        return uiModel
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
