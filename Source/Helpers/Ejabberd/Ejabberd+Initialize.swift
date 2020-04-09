//
//  Ejabberd+Initialize.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/9/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

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
