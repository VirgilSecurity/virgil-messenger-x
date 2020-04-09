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

        Notifications.post(.ejabberdAuthorized)
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

        guard !message.hasReadReceiptResponse, !message.hasDeliveryReceiptResponse else {
            return
        }

        self.unlockMutex(self.sendMutex)
    }

    func xmppStream(_ sender: XMPPStream, didFailToSend message: XMPPMessage, error: Error) {
        Log.error(error, message: "Ejabberd: message failed to send")

        guard !message.hasReadReceiptResponse, !message.hasDeliveryReceiptResponse else {
            Log.error(error, message: "Sending receipt failed")
            return
        }

        self.unlockMutex(self.sendMutex, with: error)
    }

    func xmppStream(_ sender: XMPPStream, didReceive message: XMPPMessage) {
        Log.debug("Ejabberd: Message received")

        // TODO: Add error message handling

        guard
            let author = try? message.getAuthor(),
            author != Virgil.ethree.identity,
            let body = try? message.getBody()
        else {
            return
        }

        do {
            if message.elementID != nil {
                try self.sendReceipt(to: message)
            }

            let xmppId = message.elementID ?? UUID().uuidString

            let encryptedMessage = try EncryptedMessage.import(body)

            try MessageProcessor.process(encryptedMessage, from: author, xmppId: xmppId)
        }
        catch {
            Log.error(error, message: "Message processing failed")
        }
    }

    private func sendReceipt(to message: XMPPMessage) throws {
        let author = try message.getAuthor()

        if message.hasReadReceiptRequest,
            let channel = CoreData.shared.currentChannel,
            channel.name == author
        {
            let readReceiptResponse = try message.generateReadReceiptResponse()

            self.stream.send(readReceiptResponse)
        }
        else if message.hasDeliveryReceiptRequest {
            let deliveryReceiptResponse = try message.generateDeliveryReceiptResponse()

            self.stream.send(deliveryReceiptResponse)
        }
    }
}

extension Ejabberd: XMPPMessageDeliveryReceiptsDelegate, XMPPMessageReadReceiptsDelegate {
    func xmppMessageDeliveryReceipts(_ xmppMessageDeliveryReceipts: XMPPMessageDeliveryReceipts,
                                     didReceiveReceiptResponseMessage message: XMPPMessage) {
        Log.debug("Delivery receipt received")

        do {
            let author = try message.getAuthor()
            let receiptId = try message.getDeliveryReceiptId()

            try MessageProcessor.processNewMessageState(.delivered, withId: receiptId, from: author)
        }
        catch {
            Log.error(error, message: "Delivery receipt processing failed")
        }
    }

    func xmppMessageReadReceipts(_ xmppMessageReadReceipts: XMPPMessageReadReceipts, didReceiveReadReceiptResponseMessage message: XMPPMessage) {
        Log.debug("Read receipt received")

        do {
            let author = try message.getAuthor()

            if let receiptId = message.readReceiptResponseID {
                try MessageProcessor.processNewMessageState(.read, withId: receiptId, from: author)
            }
            else {
                try MessageProcessor.processGlobalReadState(from: author)
            }
        }
        catch {
            Log.error(error, message: "Read receipt processing failed")
        }
    }
}
