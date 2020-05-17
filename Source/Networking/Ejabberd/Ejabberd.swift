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

    private let delegateQueue = DispatchQueue(label: "EjabberdDelegate")

    internal var retryConfig: RetryConfig = RetryConfig()

    internal var messageQueue = OperationQueue()
    internal var tokenProvider: EjabberdTokenProvider?
    internal var completionQueue: [CompletionQueueItem] = []

    // Ejabberd features
    internal let stream: XMPPStream = XMPPStream()
    internal let blocking = XMPPBlocking()
    private let upload = XMPPHTTPFileUpload()
    private let deliveryReceipts = XMPPMessageDeliveryReceipts()
    private let readReceipts = XMPPMessageReadReceipts()


    private let uploadJid: XMPPJID = XMPPJID(string: "upload.\(URLConstants.ejabberdHost)")!

    // Notification tokens
    static var updatedPushToken: Data?
    static var updatedVoipPushToken: Data?

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

        // Blacklist
        self.blocking.activate(self.stream)
        self.blocking.autoRetrieveBlockingListItems = true
        self.blocking.autoClearBlockingListInfo = true
        self.blocking.addDelegate(self, delegateQueue: self.delegateQueue)
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

    internal func getToken() throws -> String {
        guard let provider = self.tokenProvider else {
            throw NSError()
        }

        return try provider.getToken()
            .startSync()
            .get()
            .stringRepresentation
    }

    func queryCompleted(type: CompletionQueueItem.ActionType, error: Error?) {
        let completionItem = self.completionQueue.first { $0.type == type }
        completionItem?.completion(error)
        try? completionItem?.mutex.unlock()

        self.completionQueue = self.completionQueue.filter { $0.type != type }
    }
}
