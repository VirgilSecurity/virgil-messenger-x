//
//  Ejabberd+Messages.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/13/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import XMPPFrameworkSwift

extension Ejabberd {
    public func send(_ message: EncryptedMessage, to user: String, xmppId: String) throws {
        Log.debug("Ejabberd: Sending message")

        let user = try Ejabberd.setupJid(with: user)
        let body = try message.export()

        let message = XMPPMessage(messageType: .chat, to: user, elementID: xmppId)
        message.addBody(body)

        try self.send(message: message)
    }

    internal func send(message: XMPPMessage) throws {
        let messageOperation = EjabberdOperation(message: message, stream: self.stream, delegateQueue: self.delegateQueue)

        self.messageQueue.addOperation(messageOperation)
    }
}

extension Ejabberd {
    func xmppStream(_ sender: XMPPStream, didReceive message: XMPPMessage) {
        Log.debug("Ejabberd: Message received")

        if let error = message.errorMessage {
            Log.error(error, message: "Got an error message from Ejabberd")
            return
        }

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
}
