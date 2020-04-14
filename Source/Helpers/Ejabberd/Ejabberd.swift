//
//  Ejabberd.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 27.12.2019.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import XMPPFrameworkSwift

class Ejabberd: NSObject, XMPPStreamDelegate {
    private(set) static var shared: Ejabberd = Ejabberd()

    internal let initQueue = DispatchQueue(label: "Ejabberd")
    private let delegateQueue = DispatchQueue(label: "EjabberdDelegate")

    internal let stream: XMPPStream = XMPPStream()
    internal var error: Error?

    internal let sendMutex: Mutex = Mutex()

    private let upload = XMPPHTTPFileUpload()
    private let deliveryReceipts = XMPPMessageDeliveryReceipts()
    private let readReceipts = XMPPMessageReadReceipts()
    internal let reconnect = XMPPReconnect()

    private let uploadJid: XMPPJID = XMPPJID(string: "upload.\(URLConstants.ejabberdHost)")!

    static var updatedPushToken: Data?

    internal let serviceErrorDomain: String = "EjabberdErrorDomain"

    override init() {
        super.init()

        // Stream
        self.stream.hostName = URLConstants.ejabberdHost
        self.stream.hostPort = URLConstants.ejabberdHostPort
        self.stream.startTLSPolicy = .allowed
        self.stream.addDelegate(self, delegateQueue: self.delegateQueue)

        // Upload
        self.upload.activate(self.stream)

        // Delivery Receipts
        self.deliveryReceipts.activate(self.stream)
        self.deliveryReceipts.autoSendMessageDeliveryRequests = true
        self.deliveryReceipts.addDelegate(self, delegateQueue: self.delegateQueue)

        // Read Receipts
        self.readReceipts.activate(self.stream)
        self.readReceipts.autoSendMessageReadRequests = true
        self.readReceipts.addDelegate(self, delegateQueue: self.delegateQueue)

        // Reconnect
        self.reconnect.activate(self.stream)
        self.reconnect.autoReconnect = true
        self.reconnect.reconnectDelay = 1.0
        self.reconnect.reconnectTimerInterval = 2.0
        self.reconnect.addDelegate(self, delegateQueue: self.delegateQueue)

        try? self.sendMutex.lock()
    }

    internal func checkError() throws {
        if let error = self.error {
            throw error
        }
    }

    internal func unlockMutex(_ mutex: Mutex, with error: Error? = nil) {
        do {
            self.error = error
            try mutex.unlock()
        }
        catch {
            Log.error(error, message: "Unlocking mutex failed")
        }
    }

    public static func setupJid(with username: String) throws -> XMPPJID {
        let jidString = "\(username)@\(URLConstants.ejabberdHost)"

        guard let jid = XMPPJID(string: jidString) else {
            throw EjabberdError.jidFormingFailed
        }

        return jid
    }

    public func requestMediaSlot(name: String, size: Int) throws -> CallbackOperation<XMPPSlot> {
        return CallbackOperation { _, completion in
            self.upload.requestSlot(fromService: self.uploadJid,
                                    filename: name,
                                    size: UInt(size),
                                    contentType: "image/png")
            { (slot, iq, error) in
                completion(slot, error)
            }
        }
    }
}
