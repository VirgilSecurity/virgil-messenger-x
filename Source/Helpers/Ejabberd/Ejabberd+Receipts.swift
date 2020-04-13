//
//  Ejabberd+Receipts.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/13/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import XMPPFrameworkSwift

extension Ejabberd {
    internal func sendReceipt(to message: XMPPMessage) throws {
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

    public func sendGlobalReadReceipt(to user: String) throws {
        guard self.stream.isAuthenticated else {
            return
        }

        let jid = try Ejabberd.setupJid(with: user)

        let message = XMPPMessage.generateReadReceipt(for: jid)

        self.stream.send(message)
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
