import Chatto
import ChattoAdditions
import TwilioChatClient
import VirgilSDK

public protocol DemoMessageModelProtocol: MessageModelProtocol {
    var status: MessageStatus { get set }
}

public class MessageSender {
    public var onMessageChanged: ((_ message: DemoMessageModelProtocol) -> Void)?

    private let queue = DispatchQueue(label: "MessageSender")

    public func makeSendServiceMessageOperation(_ serviceMessage: ServiceMessage, to channel: Channel) -> CallbackOperation<Void> {
        let cards = channel.cards
        let channel = TwilioHelper.shared.currentChannel ?? TwilioHelper.shared.getChannel(channel)

        let plaintext = serviceMessage.message.base64EncodedString()

        // FIXME
        let ciphertext = try! VirgilHelper.shared.encrypt(plaintext, cards: cards)

        return TwilioHelper.shared.send(ciphertext: ciphertext, messages: channel!.messages!, type: .regular)
    }

    public func send(message: Message, withId id: Int) throws -> DemoMessageModelProtocol {
        let cards = message.channel.cards
        let channel = TwilioHelper.shared.currentChannel ?? TwilioHelper.shared.getChannel(message.channel)

        guard let messages = channel?.messages else {
            throw NSError()
        }

        let uiModel = message.exportAsUIModel(withId: id, status: .sending)

        self.queue.async {
            do {
                switch message.type {
                case .text:
                    guard let plaintext = message.body else {
                        throw NSError()
                    }

                    let ciphertext = message.channel.type == .group ?
                        "\(TwilioHelper.shared.username): \(plaintext)" :
                    try VirgilHelper.shared.encrypt(plaintext, cards: cards)

                    try TwilioHelper.shared.send(ciphertext: ciphertext, messages: messages, type: .regular).startSync().getResult()
                case .photo:
                    break
                case .audio:
                    break
                }

                try CoreDataHelper.shared.save(message)

                self.updateMessage(uiModel, status: .success)
            } catch {
                Log.error(error.localizedDescription)
                Log.error("\(error)")
                self.updateMessage(uiModel, status: .failed)
            }
        }

        return uiModel
    }

    private func updateMessage(_ message: DemoMessageModelProtocol, status: MessageStatus) {
        if message.status != status {
            message.status = status
            self.notifyMessageChanged(message)
        }
    }

    private func notifyMessageChanged(_ message: DemoMessageModelProtocol) {
        DispatchQueue.main.async {
            self.onMessageChanged?(message)
        }
    }
}
