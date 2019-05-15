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

    public static func makeSendServiceMessageOperation(_ plaintext: String, to coreChannel: Channel) -> CallbackOperation<Void> {
//        let channel = TwilioHelper.shared.getChannel(card.identity)
        let twilioChannel = TwilioHelper.shared.getChannel(coreChannel.name)

        switch coreChannel.type {
        case .single:
            let ciphertext = try! VirgilHelper.shared.encrypt(plaintext, card: coreChannel.cards.first!)

            return TwilioHelper.shared.send(ciphertext: ciphertext, messages: twilioChannel!.messages!, type: .service)
        case .group:
            let ciphertext = try! VirgilHelper.shared.encryptGroup(plaintext, channel: coreChannel)

            return TwilioHelper.shared.send(ciphertext: ciphertext, messages: twilioChannel!.messages!, type: .service)
        }
    }

    public func sendChangeMembers(message: Message) -> CallbackOperation<Void> {
        let channel = TwilioHelper.shared.currentChannel!
        let messages = channel.messages!

//        guard message.type == .changeMembers else {
//            throw NSError()
//        }

        let plaintext = "\(TwilioHelper.shared.username) \(message.body!)"
        let ciphertext = try! VirgilHelper.shared.encryptGroup(plaintext, channel: message.channel)

        return TwilioHelper.shared.send(ciphertext: ciphertext,
                                        messages: messages,
                                        type: .service,
                                        sessionId: message.channel.sessionId)
    }

    public func send(message: Message, withId id: Int) throws -> DemoMessageModelProtocol {
        let cards = message.channel.cards

        guard let channel = TwilioHelper.shared.currentChannel ?? TwilioHelper.shared.getChannel(message.channel.name),
            let messages = channel.messages else {
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
                        ciphertext = try VirgilHelper.shared.encryptGroup(plaintext, channel: message.channel)
                    case .single:
                        ciphertext = try VirgilHelper.shared.encrypt(plaintext, card: cards.first!)
                    }

                    try TwilioHelper.shared.send(ciphertext: ciphertext,
                                                 messages: messages,
                                                 type: .regular,
                                                 sessionId: message.channel.sessionId).startSync().getResult()
                case .photo:
                    break
                case .audio:
                    break
                case .changeMembers:
                    guard var plaintext = message.body else {
                        throw NSError()
                    }

                    plaintext = "\(TwilioHelper.shared.username) \(plaintext)"
                    let ciphertext = try VirgilHelper.shared.encryptGroup(plaintext, channel: message.channel)

                    try TwilioHelper.shared.send(ciphertext: ciphertext,
                                                 messages: messages,
                                                 type: .service,
                                                 sessionId: message.channel.sessionId).startSync().getResult()
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
