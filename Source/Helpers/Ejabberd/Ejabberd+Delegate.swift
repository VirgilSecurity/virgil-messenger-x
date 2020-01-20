//
//  Ejabberd+delegate.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 03.01.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import XMPPFrameworkSwift
import VirgilSDK

extension Ejabberd: XMPPStreamDelegate {
    func xmppStreamWillConnect(_ sender: XMPPStream) {
        Log.debug("Ejabberd: Connecting...")
    }

    func xmppStreamDidConnect(_ stream: XMPPStream) {
        Log.debug("Ejabberd: Connected")

        self.state = .connected
        self.unlockMutex(self.initializeMutex)
    }

    func xmppStreamConnectDidTimeout(_ sender: XMPPStream) {
        // TODO: schedule retry
        Log.debug("Ejabberd: Connect reached timeout")

        self.state = .disconnected
        self.unlockMutex(self.initializeMutex, with: EjabberdError.connectionTimeout)
    }

    func xmppStreamDidDisconnect(_ sender: XMPPStream, withError error: Error?) {
        if let error = error {
            Log.debug("Ejabberd disconnected with error - \(error.localizedDescription)")

            // TODO: schedule retry
            Configurator.configure()
        }
        else {
            Log.debug("Ejabberd disconnected")
        }

        let unlock = self.state == .connecting
        self.state = .disconnected

        if unlock {
            self.unlockMutex(self.initializeMutex, with: error)
        }
    }

    func xmppStreamDidAuthenticate(_ sender: XMPPStream) {
        Log.debug("Ejabberd: Authenticated")
        self.stream.send(XMPPPresence())

        self.unlockMutex(self.initializeMutex)
    }

    func xmppStream(_ sender: XMPPStream, didNotAuthenticate error: DDXMLElement) {
        Log.debug("Ejabberd: Authentication failed \(error)")

        let description = error.stringValue ?? "Authentication unknown error"

        let error = NSError(domain: self.serviceErrorDomain,
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: description])

        self.unlockMutex(self.initializeMutex, with: error)
    }
}

extension Ejabberd {
    func xmppStream(_ sender: XMPPStream, didSend message: XMPPMessage) {
        Log.debug("Ejabberd: Message sent")

        self.unlockMutex(self.sendMutex)
    }

    func xmppStream(_ sender: XMPPStream, didFailToSend message: XMPPMessage, error: Error) {
        Log.error("Ejabberd: Message failed to send \(error)")

        self.unlockMutex(self.sendMutex, with: error)
    }

    func xmppStream(_ sender: XMPPStream, didReceive message: XMPPMessage) {
        Log.debug("Ejabberd: Message received")

        self.queue.async {
            do {
                let author = try message.getAuthor()
                let encryptedMessage = try EncryptedMessage.import(message)

                guard let message = try MessageProcessor.process(encryptedMessage, from: author),
                    let currentChannel = CoreData.shared.currentChannel,
                    currentChannel.name == author else {
                        // TODO: Check if needed
                        return Notifications.post(.chatListUpdated)
                }

                Notifications.post(message: message)
            }
            catch {
                Log.error("\(error)")
            }
        }
    }
}
