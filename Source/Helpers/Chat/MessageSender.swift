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

    public static func sendServiceMessage(_ message: ServiceMessage, to coreChannel: Channel) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let twilioChannel = try Twilio.shared.getChannel(coreChannel)

                let plaintext = try message.export()

                let ciphertext: String
                switch coreChannel.type {
                case .single:
                    ciphertext = try Virgil.shared.encrypt(plaintext, card: coreChannel.cards.first!)
                case .group:
                    ciphertext = try Virgil.shared.encryptGroup(plaintext, channel: coreChannel)
                }

                twilioChannel.send(ciphertext: ciphertext,
                                   type: .service,
                                   identifier: message.identifier).start(completion: completion)
            } catch {
                completion(nil, error)
            }
        }
    }

    public static func sendServiceMessage(to cards: [Card], ticket: ServiceMessage) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            guard !cards.isEmpty else {
                completion((), nil)
                return
            }

            var operations: [CallbackOperation<Void>] = []
            for card in cards {
                guard let channel = CoreData.shared.getSingleChannel(with: card.identity) else {
                    continue
                }

                let sendOperation = MessageSender.sendServiceMessage(ticket, to: channel)
                operations.append(sendOperation)
            }

            let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

            operations.forEach {
                completionOperation.addDependency($0)
            }

            let queue = OperationQueue()
            queue.addOperations(operations + [completionOperation], waitUntilFinished: false)
        }
    }

    public func sendChangeMembers(message: Message, identifier: String) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let channel = try Twilio.shared.getCurrentChannel()

                let body = try message.getBody()

                channel.send(ciphertext: body, type: .service, identifier: identifier).start(completion: completion)
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
                        ciphertext = try Virgil.shared.encryptGroup(plaintext, channel: message.channel)
                    case .single:
                        ciphertext = try Virgil.shared.encrypt(plaintext, card: cards.first!)
                    }

                    try channel.send(ciphertext: ciphertext, type: .regular).startSync().getResult()
                case .photo:
                    break
                case .audio:
                    break
                case .changeMembers:
                    let plaintext = try message.getBody()

                    let ciphertext = try Virgil.shared.encryptGroup(plaintext, channel: message.channel)

                    try channel.send(ciphertext: ciphertext, type: .service).startSync().getResult()
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
