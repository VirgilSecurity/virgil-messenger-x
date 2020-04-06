//
//  XMPPMessage.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 03.01.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import XMPPFrameworkSwift

extension XMPPMessage {
    func getBody() throws -> String {
        guard let body = self.body else {
            throw EjabberdError.missingBody
        }

        return body
    }

    func getAuthor() throws -> String {
        guard let author = self.from?.user else {
            throw EjabberdError.missingAuthor
        }

        return author
    }

    func getDeliveryReceiptId() throws -> String {
        guard let receiptId = self.deliveryReceiptResponseID else {
            throw EjabberdError.missingElementId
        }

        return receiptId
    }

    func generateReadReceiptResponse() throws -> XMPPMessage {
        guard let readReceiptResponse = self.generateReadReceiptResponse else {
            throw NSError()
        }

        return readReceiptResponse
    }

    func generateDeliveryReceiptResponse() throws -> XMPPMessage {
        guard let deliveryReceiptResponse = self.generateDeliveryReceiptResponse else {
            throw NSError()
        }

        return deliveryReceiptResponse
    }
}
