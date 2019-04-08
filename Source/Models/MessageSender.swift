import Chatto
import ChattoAdditions
import TwilioChatClient

public protocol DemoMessageModelProtocol: MessageModelProtocol {
    var status: MessageStatus { get set }
}

public class MessageSender {
    public var onMessageChanged: ((_ message: DemoMessageModelProtocol) -> Void)?
    
    public func sendMessage(_ message: DemoMessageModelProtocol) {
        switch message {
        case is DemoTextMessageModel:
            let textMessage = message as! DemoTextMessageModel

            let text = textMessage.body

            if let encrypted = VirgilHelper.shared.encrypt(text) {
                self.messageStatus(ciphertext: encrypted, message: textMessage)
            }
        case is DemoPhotoMessageModel:
            let photoMessage = message as! DemoPhotoMessageModel
            guard let photoData = photoMessage.image.jpegData(compressionQuality: 0.0) else {
                Log.error("Converting image to JPEG failed")
                return
            }
            
            if let encrypted = VirgilHelper.shared.encrypt(photoData.base64EncodedString()) {
                guard let cipherData = encrypted.data(using: .utf8) else {
                    Log.error("String to Data failed")
                    return
                }

                self.messageStatus(of: photoMessage, with: cipherData)
            }
        case is DemoAudioMessageModel:
            let audioMessage = message as! DemoAudioMessageModel
            if let encrypted = VirgilHelper.shared.encrypt(audioMessage.audio.base64EncodedString()) {
                guard let cipherData = encrypted.data(using: .utf8) else {
                    Log.error("String to Data failed")
                    return
                }

                self.messageStatus(of: audioMessage, with: cipherData)
            }
        default:
            Log.error("Unknown message model")
        }
    }
}

extension MessageSender {
    private func messageStatus(ciphertext: String, message: DemoTextMessageModel) {
        switch message.status {
        case .success:
            break
        case .failed:
            self.updateMessage(message, status: .sending)
            self.messageStatus(ciphertext: ciphertext, message: message)
        case .sending:
            if let messages = TwilioHelper.shared.currentChannel?.messages {
                let options = TCHMessageOptions().withBody(ciphertext)
                Log.debug("sending \(ciphertext)")
                messages.sendMessage(with: options) { result, msg in
                    if result.isSuccessful() {
                        self.updateMessage(message, status: .success)
                        try! CoreDataHelper.shared.saveTextMessage(message.body, isIncoming: false, date: message.date)
                    } else {
                        Log.error("error sending: Twilio cause")
                        self.updateMessage(message, status: .failed)
                    }
                }
            } else {
                Log.error("can't get channel messages")
            }
        }
    }

    private func messageStatus(of message: DemoPhotoMessageModel, with cipherphoto: Data) {
        switch message.status {
        case .success:
            break
        case .failed:
            self.updateMessage(message, status: .sending)
            self.messageStatus(of: message, with: cipherphoto)
        case .sending:
            if let messages = TwilioHelper.shared.currentChannel?.messages {
                let inputStream = InputStream(data: cipherphoto)
                let options = TCHMessageOptions().withMediaStream(inputStream,
                                                                  contentType: TwilioHelper.MediaType.photo.rawValue,
                                                                  defaultFilename: "image.bmp",
                                                                  onStarted: {
                                                                    Log.debug("Media upload started")
                },
                                                                  onProgress: { (bytes) in
                                                                    Log.debug("Media upload progress: \(bytes)")
                }) { (mediaSid) in
                    Log.debug("Media upload completed")
                }
                Log.debug("sending photo")
                messages.sendMessage(with: options) { result, msg in
                    if result.isSuccessful() {
                        self.updateMessage(message, status: .success)

                        guard let imageData = message.image.jpegData(compressionQuality: 0.0) else {
                            Log.error("failed getting data from image")
                            return
                        }

                        try! CoreDataHelper.shared.saveMediaMessage(imageData, isIncoming: false, date: message.date, type: .photo)
                    } else {
                        if let error = result.error {
                            Log.error("error sending: \(error.localizedDescription) with \(error.code)")
                        } else {
                            Log.error("error sending: Twilio service error")
                        }
                        self.updateMessage(message, status: .failed)
                    }
                }
            } else {
                Log.error("can't get channel messages")
            }
        }
    }

    private func messageStatus(of message: DemoAudioMessageModel, with cipherdata: Data) {
        switch message.status {
        case .success:
            break
        case .failed:
            self.updateMessage(message, status: .sending)
            self.messageStatus(of: message, with: cipherdata)
        case .sending:
            if let messages = TwilioHelper.shared.currentChannel?.messages {
                let inputStream = InputStream(data: cipherdata)
                let options = TCHMessageOptions().withMediaStream(inputStream,
                                                                  contentType: TwilioHelper.MediaType.audio.rawValue,
                                                                  defaultFilename: "audio.mp4",
                                                                  onStarted: { Log.debug("Media upload started") },
                                                                  onProgress: { Log.debug("Media upload progress: \($0)") },
                                                                  onCompleted: { _ in Log.debug("Media upload completed") })
                Log.debug("sending audio")
                messages.sendMessage(with: options) { result, msg in
                    if result.isSuccessful() {
                        self.updateMessage(message, status: .success)

                        try! CoreDataHelper.shared.saveMediaMessage(message.audio, isIncoming: false, date: message.date, type: .audio)
                    } else {
                        if let error = result.error {
                            Log.error("error sending: \(error.localizedDescription) with \(error.code)")
                        } else {
                            Log.error("error sending: Twilio service error")
                        }
                        self.updateMessage(message, status: .failed)
                    }
                }
            } else {
                Log.error("can't get channel messages")
            }
        }
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