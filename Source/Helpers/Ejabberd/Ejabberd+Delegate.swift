//
//  Ejabberd+delegate.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 03.01.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import XMPPFrameworkSwift
import VirgilSDK
import Crashlytics

extension Ejabberd: XMPPStreamDelegate {
    func xmppStreamWillConnect(_ sender: XMPPStream) {
        Log.debug("Ejabberd: Connecting...")
    }

    func xmppStreamDidConnect(_ stream: XMPPStream) {
        Log.debug("Ejabberd: Connected")

        self.state = .connected
        self.shouldRetry = true
        self.unlockMutex(self.initializeMutex)
    }

    func xmppStreamConnectDidTimeout(_ sender: XMPPStream) {
        Log.debug("Ejabberd: Connect reached timeout")

        self.state = .disconnected
        
        Crashlytics.sharedInstance().recordError(EjabberdError.connectionTimeout)
        
        self.unlockMutex(self.initializeMutex, with: UserFriendlyError.connectionIssue)
    }

    func xmppStreamDidDisconnect(_ sender: XMPPStream, withError error: Error?) {
        let erroredUnlock = self.state == .connecting
        self.state = .disconnected

        if let error = error {
            Log.debug("Ejabberd disconnected with error - \(error.localizedDescription)")

            if erroredUnlock {
                Crashlytics.sharedInstance().recordError(error)

                self.unlockMutex(self.initializeMutex, with: UserFriendlyError.connectionIssue)
            }
            else {
                self.retryInitialize(error: error)
            }
        }
        else {
            Log.debug("Ejabberd disconnected")
            self.unlockMutex(self.initializeMutex)
        }
    }

    func xmppStreamDidAuthenticate(_ sender: XMPPStream) {
        Log.debug("Ejabberd: Authenticated")
        self.set(status: .online)

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

        do {
            let author = try message.getAuthor()
            
            guard author != Virgil.ethree.identity else {
                return
            }
            
            let body = try message.getBody()
            let encryptedMessage = try EncryptedMessage.import(body)

            try MessageProcessor.process(encryptedMessage, from: author)
        }
        catch {
            Log.error("\(error)")
        }
    }
}
