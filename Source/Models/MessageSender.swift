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

    public static func makeSendServiceMessageOperation(_ data: Data, to card: Card) -> CallbackOperation<Void> {
        let channel = TwilioHelper.shared.currentChannel ?? TwilioHelper.shared.getChannel(card.identity)

        let plaintext = data.base64EncodedString()

        // FIXME
        let ciphertext = try! VirgilHelper.shared.encrypt(plaintext, card: card)

        return TwilioHelper.shared.send(ciphertext: ciphertext, messages: channel!.messages!, type: .service)
    }

    public func send(message: Message, withId id: Int) throws -> DemoMessageModelProtocol {
        let cards = message.channel.cards
        let channelCandidate = TwilioHelper.shared.currentChannel ?? TwilioHelper.shared.getChannel(message.channel.name)

        guard let channel = channelCandidate, let messages = channel.messages else {
            throw NSError()
        }

        let uiModel = message.exportAsUIModel(withId: id, status: .sending)

        self.queue.async {
            do {
                switch message.type {
                case .text:
                    guard var plaintext = message.body else {
                        throw NSError()
                    }

                    let ciphertext: String
                    switch message.channel.type {
                    case .group:
                        plaintext = "\(TwilioHelper.shared.username): \(plaintext)"
                        ciphertext = try VirgilHelper.shared.encrypt(plaintext, channel: message.channel)
                    case .single:
                        ciphertext = try VirgilHelper.shared.encrypt(plaintext, card: cards.first!)
                    }

                    try TwilioHelper.shared.send(ciphertext: ciphertext, messages: messages, type: .regular).startSync().getResult()
                case .photo:
                    break
                case .audio:
                    break
                }

                try CoreDataHelper.shared.save(message)

                self.updateMessage(uiModel, status: .success)
            } catch {
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
