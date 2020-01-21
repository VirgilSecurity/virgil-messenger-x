//
//  Ejabberd.swift
//  Morse
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
}

class Ejabberd: NSObject {
    private(set) static var shared: Ejabberd = Ejabberd()

    // FIXME
    private let delegateQueue = DispatchQueue(label: "EjabberdDelegate")

    internal let stream: XMPPStream = XMPPStream()
    internal var error: Error?
    internal let initializeMutex: Mutex = Mutex()
    internal let sendMutex: Mutex = Mutex()
    internal let receiveQueue = DispatchQueue(label: "Ejabberd")   // FIXME
    internal var state: State = .disconnected
    internal var shouldRetry: Bool = true

    internal let serviceErrorDomain: String = "EjabberdErrorDomain"

    internal enum State {
        case connected
        case connecting
        case disconnected
    }

    override init() {
        super.init()

        self.stream.hostName = URLConstants.ejabberdHost
        self.stream.hostPort = URLConstants.ejabberdHostPort
        self.stream.startTLSPolicy = URLConstants.ejabberdTSLPolicy
        self.stream.addDelegate(self, delegateQueue: self.delegateQueue)

        try? self.initializeMutex.lock()
        try? self.sendMutex.lock()
    }

    public func initialize(identity: String) throws {
        self.stream.myJID = try Ejabberd.setupJid(with: identity)

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
            Log.error("Ejabberd: \(error)")
        }
    }

    public static func setupJid(with username: String) throws -> XMPPJID {
        let jidString = "\(username)@\(URLConstants.ejabberdHost)"

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

    public func send(_ message: EncryptedMessage, to user: String) throws {
        Log.debug("Ejabberd: Sending message")

        let user = try Ejabberd.setupJid(with: user)

        let body = try message.export()

        let message = XMPPMessage(messageType: .chat, to: user)
        message.addBody(body)

        self.stream.send(message)

        try self.sendMutex.lock()

        try self.checkError()
    }
}
