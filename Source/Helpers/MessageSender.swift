import Chatto
import ChattoAdditions
import VirgilSDK

public protocol UIMessageModelProtocol: MessageModelProtocol {
    var status: MessageStatus { get set }
}

public class MessageSender {
    public var onMessageChanged: ((_ message: UIMessageModelProtocol) -> Void)?

    private let queue = DispatchQueue(label: "MessageSender")

    private func encryptThenSend(message: Message, date: Date, channel: Storage.Channel) throws {
        let exported = try message.exportAsJsonData()

        let ciphertext = try Virgil.ethree.authEncrypt(data: exported, for: channel.getCard())

        let encryptedMessage = EncryptedMessage(ciphertext: ciphertext, date: date)
        
        try Ejabberd.shared.send(encryptedMessage, to: channel.name)
    }
    
    public func send(text: Message.Text, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        do {
            try self.encryptThenSend(message: Message.text(text), date: date, channel: channel)
            
            _ = try Storage.shared.createTextMessage(text.body, in: channel, isIncoming: false, date: date)
            
            completion(nil)
        }
        catch {
            completion(error)
        }
    }
    
    public func send(callOffer: Message.CallOffer, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                try self.encryptThenSend(message: Message.callOffer(callOffer), date: date, channel: channel)
                
                let storageMessage = try Storage.shared.createCallMessage(in: channel, isIncoming: false, date: date)
                
                Notifications.post(message: storageMessage)

                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }
    
    public func send(callAnswer: Message.CallAnswer, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                try self.encryptThenSend(message: Message.callAnswer(callAnswer), date: date, channel: channel)
                
                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }

    public func send(iceCandidate: Message.IceCandidate, date: Date, channel: Storage.Channel, completion: @escaping (Error?) -> Void) {
        self.queue.async {
            do {
                try self.encryptThenSend(message: Message.iceCandidate(iceCandidate), date: date, channel: channel)
                
                completion(nil)
            }
            catch {
                completion(error)
            }
        }
    }
}
