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
        self.shouldRetry = true
        self.unlockMutex(self.initializeMutex)
    }

    func xmppStreamConnectDidTimeout(_ sender: XMPPStream) {
        self.state = .disconnected
        
        Log.error(EjabberdError.connectionTimeout, message: "Ejabberd connection reached timeout")
        
        self.unlockMutex(self.initializeMutex, with: UserFriendlyError.connectionIssue)
    }

    func xmppStreamDidDisconnect(_ sender: XMPPStream, withError error: Error?) {
        let erroredUnlock = self.state == .connecting
        self.state = .disconnected

        if let error = error {
            Log.error(error, message: "Ejabberd disconnected")
            
            if erroredUnlock {
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
        Log.error(error, message: "Ejabberd: message failed to send")

        self.unlockMutex(self.sendMutex, with: error)
    }

    func xmppStream(_ sender: XMPPStream, didReceive message: XMPPMessage) {
        Log.debug("Ejabberd: Message received")
        
        // TODO: Add error message handling
        
        guard
            let author = try? message.getAuthor(),
            author != Virgil.ethree.identity,
            let body = try? message.getBody(),
            let xmppId = message.elementID
        else {
            return
        }
        
        do {
            let encryptedMessage = try EncryptedMessage.import(body)

            try MessageProcessor.process(encryptedMessage, from: author, xmppId: xmppId)
        }
        catch {
            Log.error(error, message: "Message processing failed")
        }
    }
}

extension Ejabberd: XMPPMessageDeliveryReceiptsDelegate {
    func xmppMessageDeliveryReceipts(_ xmppMessageDeliveryReceipts: XMPPMessageDeliveryReceipts,
                                     didReceiveReceiptResponseMessage message: XMPPMessage) {
        Log.debug("Delivery receipt received")
        
        do {
            let author = try message.getAuthor()
            let receiptId = try message.getReceiptId()
            
            try MessageProcessor.processReceipt(withId: receiptId, from: author)
        }
        catch {
            Log.error(error, message: "Delivery receipt processing failed")
        }
    }
}
