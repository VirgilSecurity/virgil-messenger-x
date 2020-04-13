//
//  Ejabberd+Initialize.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/9/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import XMPPFrameworkSwift

extension Ejabberd {
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

    public func disconect() throws {
        Log.debug("Ejabberd: Disconnecting")

        guard self.stream.isConnected else {
            return
        }

        self.stream.disconnect()

        try self.initializeMutex.lock()

        try self.checkError()
    }
}

extension Ejabberd {
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
