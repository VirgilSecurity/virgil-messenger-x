//
//  Ejabberd+Connection.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/9/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import XMPPFrameworkSwift

extension Ejabberd {
    internal enum ConnectionState {
        case connected
        case connecting
        case disconnected
    }

    internal var state: ConnectionState {
        let result: ConnectionState

        if self.stream.isAuthenticated {
            result = .connected
        }
        else if self.stream.isConnected || self.stream.isConnecting || self.stream.isAuthenticating {
            result = .connecting
        }
        else {
            result = .disconnected
        }

        return result
    }
    
    public func startInitializing(identity: String) {
        do {
            self.stream.myJID = try Ejabberd.setupJid(with: identity)

            self.initialize()
        }
        catch {
            Log.error(error, message: "Jid forming failed")
            Notifications.post(error: error)
        }
    }

    private func initialize(after: TimeInterval = 0) {
        self.initQueue.asyncAfter(deadline: .now() + after) {
            do {
                if !self.stream.isConnected {
                    try self.stream.connect(withTimeout: 20)
                }
            }
            catch {
                Log.error(error, message: "Ejabberd initialize failed")
                Notifications.post(error: error)
            }
        }
    }

    private func setupRetry() {
        if self.shouldRetry {
            self.initialize(after: 1)
        }
        else {
            self.shouldRetry = true
        }
    }

    public func disconect() throws {
        Log.debug("Ejabberd: Disconnecting")

        guard self.stream.isConnected else {
            self.stream.abortConnecting()
            return
        }

        self.shouldRetry = false

        self.stream.disconnect()
    }
}

extension Ejabberd {
    func xmppStreamWillConnect(_ sender: XMPPStream) {
        Log.debug("Ejabberd: Connecting...")
    }

    func xmppStreamDidConnect(_ stream: XMPPStream) {
        Log.debug("Ejabberd: Connected")

        do {
            if !self.stream.isAuthenticated {
                guard let identity = self.stream.myJID?.user else {
                    throw EjabberdError.missingStreamJID
                }

                let token = try Virgil.shared.client.getEjabberdToken(identity: identity)
                try self.stream.authenticate(withPassword: token)
            }
        }
        catch {
            Log.error(error, message: "Authenticating stream failed")
        }
    }

    func xmppStreamConnectDidTimeout(_ sender: XMPPStream) {
        Log.error(EjabberdError.connectionTimeout, message: "Ejabberd connection reached timeout")

        self.setupRetry()
    }

    func xmppStreamDidDisconnect(_ sender: XMPPStream, withError error: Error?) {
        if let error = error {
            Log.error(error, message: "Ejabberd disconnected")
        }
        else {
            Log.debug("Ejabberd disconnected")
        }

        Notifications.post(.connectionStateChanged)

        self.setupRetry()
    }

    func xmppStreamDidAuthenticate(_ sender: XMPPStream) {
        Log.debug("Ejabberd: Authenticated")

        self.set(status: .online)

        do {
            try self.registerForNotifications()
        }
        catch {
            Log.error(error, message: "Registering for notifications failed")
        }

        Notifications.post(.connectionStateChanged)
    }

    func xmppStream(_ sender: XMPPStream, didNotAuthenticate error: DDXMLElement) {
        let description = error.stringValue ?? "Authentication unknown error"

        let error = NSError(domain: self.serviceErrorDomain,
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: description])

        Log.error(error, message: "Ejabberd authentication failed")

        Notifications.post(.connectionStateChanged)
    }
}
