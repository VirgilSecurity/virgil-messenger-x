//
//  Ejabberd.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 27.12.2019.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import XMPPFrameworkSwift

public enum EjabberdError: Int, Error {
    case connectionTimeout = 1
    case missingBody = 2
    case missingAuthor = 3
    case jidFormingFailed = 4
    case missingStreamJID = 5
    case missingElementId = 6
    case generatingReadResponseFailed = 7
    case generatingDeliveryResponseFailed = 8
}

// TODO: Split file
class Ejabberd: NSObject {
    private(set) static var shared: Ejabberd = Ejabberd()

    private let delegateQueue = DispatchQueue(label: "EjabberdDelegate")

    internal let stream: XMPPStream = XMPPStream()
    internal var error: Error?
    internal let initializeMutex: Mutex = Mutex()
    internal let sendMutex: Mutex = Mutex()
    internal var state: State = .disconnected
    internal var shouldRetry: Bool = true

    internal let upload = XMPPHTTPFileUpload()
    internal let deliveryReceipts = XMPPMessageDeliveryReceipts()
    internal let readReceipts = XMPPMessageReadReceipts()

//    private let uploadJid: XMPPJID = XMPPJID(string: "upload.\(URLConstants.ejabberdHost)")!

    static var updatedPushToken: Data?

    internal let serviceErrorDomain: String = "EjabberdErrorDomain"

    internal enum State {
        case connected
        case connecting
        case disconnected
    }

    enum Status {
        case online
        case unavailable
    }

    override init() {
        super.init()

        self.stream.hostPort = URLConstants.ejabberdHostPort
        self.stream.startTLSPolicy = .allowed
        self.stream.addDelegate(self, delegateQueue: self.delegateQueue)

        self.upload.activate(self.stream)

        self.deliveryReceipts.activate(self.stream)
        self.deliveryReceipts.autoSendMessageDeliveryRequests = true
        self.deliveryReceipts.addDelegate(self, delegateQueue: self.delegateQueue)

        self.readReceipts.activate(self.stream)
        self.readReceipts.autoSendMessageReadRequests = true
        self.readReceipts.addDelegate(self, delegateQueue: self.delegateQueue)

        try? self.initializeMutex.lock()
        try? self.sendMutex.lock()
    }

    public func initialize(identity: String, host: String) throws {
        self.stream.myJID = try Ejabberd.setupJid(with: identity, host: host)
        self.stream.hostName = host

        try self.initialize()
    }

    internal func initialize() throws {
        guard let identity = self.stream.myJID?.user else {
            throw EjabberdError.missingStreamJID
        }

        if !self.stream.isConnected {
            self.state = .connecting
            try self.stream.connect(withTimeout: 20)
            try self.initializeMutex.lock()

            try self.checkError()
        }

        if !self.stream.isAuthenticated {
            let token = try Virgil.shared.client.getEjabberdToken(identity: identity)
            try self.stream.authenticate(withPassword: token)
            try self.initializeMutex.lock()

            try self.checkError()
        }

        try self.registerForNotifications()
    }

    internal func retryInitialize(error: Error) {
        guard self.shouldRetry else {
            Notifications.post(error: error)
            return
        }

        self.shouldRetry = false

        DispatchQueue.main.async {
            Configurator.configure()
        }
    }

    private func checkError() throws {
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

    public static func setupJid(with username: String, host: String) throws -> XMPPJID {
        let jidString = "\(username)@\(host)"

        guard let jid = XMPPJID(string: jidString) else {
            throw EjabberdError.jidFormingFailed
        }

        return jid
    }

    public func disconect() throws {
        Log.debug("Ejabberd: Disconnecting")

        guard self.stream.isConnected else {
            return
        }

        self.stream.disconnect()

        try self.initializeMutex.lock()

        try self.checkError()
    }

    public func send(_ message: EncryptedMessage, to user: String, xmppId: String) throws {
        Log.debug("Ejabberd: Sending message")

        guard let host = CoreData.shared.currentAccount?.ejabberdHost else {
            throw NSError()
        }

        let user = try Ejabberd.setupJid(with: user, host: host)

        let body = try message.export()

        let message = XMPPMessage(messageType: .chat, to: user, elementID: xmppId)
        message.addBody(body)

        try self.send(message: message, to: user)
    }

    internal func send(message: XMPPMessage, to user: XMPPJID) throws {
        self.stream.send(message)

        try self.sendMutex.lock()

        try self.checkError()
    }

    public func sendGlobalReadResponse(to user: String) throws {
        guard self.stream.isAuthenticated else {
            return
        }

        let host = CoreData.shared.currentAccount!.ejabberdHost

        let jid = try Ejabberd.setupJid(with: user, host: host)

        let message = XMPPMessage.generateReadReceipt(for: jid)

        self.stream.send(message)
    }

    public func set(status: Status) {
        let presence: XMPPPresence

        switch status {
        case .online:
            presence = XMPPPresence()
        case .unavailable:
            presence = XMPPPresence(type: .unavailable,
                                    show: nil,
                                    status: nil,
                                    idle: nil,
                                    to: nil)
        }

        self.stream.send(presence)
    }

    public func requestMediaSlot(name: String, size: Int) throws -> CallbackOperation<XMPPSlot> {
        return CallbackOperation { _, completion in
            let host = CoreData.shared.currentAccount!.ejabberdHost

            let uploadJID = XMPPJID(string: "upload.\(host)")!

            self.upload.requestSlot(fromService: uploadJID,
                                    filename: name,
                                    size: UInt(size),
                                    contentType: "image/png")
            { (slot, iq, error) in
                completion(slot, error)
            }
        }
    }
}

extension Ejabberd {
    func registerForNotifications(deviceToken: Data? = nil) throws {
        guard let deviceToken = deviceToken ?? Ejabberd.updatedPushToken else {
            return
        }

        let pushHost = CoreData.shared.currentAccount!.pushHost

        guard let pushServerJID = XMPPJID(string: pushHost) else {
            throw EjabberdError.jidFormingFailed
        }

        let deviceId = deviceToken.hexEncodedString()

        let options = ["device_id": deviceId,
                       "service": "apns",
                       "mutable_content": "true",
                       "sound": "default",
                       "push_mode": "prod",
                       "topic": Constants.KeychainGroup]

        let element = XMPPIQ.enableNotificationsElement(with: pushServerJID,
                                                        node: Constants.pushesNode,
                                                        options: options)

        self.stream.send(element)
    }

    func deregisterFromNotifications() throws {
        let pushHost = CoreData.shared.currentAccount!.pushHost

        guard let pushServerJID = XMPPJID(string: pushHost) else {
            throw EjabberdError.jidFormingFailed
        }

        let element = XMPPIQ.disableNotificationsElement(with: pushServerJID, node: Constants.pushesNode)

        self.stream.send(element)
    }
}
