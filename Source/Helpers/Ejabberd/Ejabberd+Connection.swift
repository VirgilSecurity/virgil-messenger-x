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

    internal struct RetryConfig {
        var shouldRetry: Bool = true
        var reconnectDelay: ReconnectDelay = .noDelay

        enum ReconnectDelay: TimeInterval {
            case noDelay = 0
            case shortDelay = 1
        }
    }
}

extension Ejabberd {
    public func startInitializing(identity: String) {
        do {
            self.stream.myJID = try Ejabberd.setupJid(with: identity)
            self.retryConfig = RetryConfig()

            self.initialize()
        }
        catch {
            Log.error(error, message: "Jid forming failed")
            Notifications.post(error: error)
        }
    }

    private func initialize(after: TimeInterval = RetryConfig.ReconnectDelay.noDelay.rawValue) {
        self.initQueue.asyncAfter(deadline: .now() + after) {
            do {
                guard self.state != .connecting else {
                    return
                }

                try self.stream.connect(withTimeout: 10)
            }
            catch {
                Log.error(error, message: "Ejabberd initialize failed")
                Notifications.post(error: error)
            }
        }
    }

    private func setupRetry() {
        if self.retryConfig.shouldRetry {
            self.initialize(after: self.retryConfig.reconnectDelay.rawValue)
            self.retryConfig.reconnectDelay = .shortDelay
        }
        else {
            self.retryConfig.shouldRetry = true
        }
    }

    public func disconect() throws {
        Log.debug("Ejabberd: Disconnecting")

        if !self.stream.isConnected {
            self.stream.abortConnecting()
        }

        self.retryConfig.shouldRetry = false

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
            guard !self.stream.isAuthenticating, !self.stream.isAuthenticated else {
                return
            }

            guard let identity = self.stream.myJID?.user else {
                throw EjabberdError.missingStreamJID
            }

            let token = try Virgil.shared.client.getEjabberdToken(identity: identity)
            try self.stream.authenticate(withPassword: token)
        }
        catch {
            Log.error(error, message: "Authenticating stream failed")
        }
    }

    func xmppStreamConnectDidTimeout(_ sender: XMPPStream) {
        Log.debug("Ejabberd connecting reached timeout")
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

        self.registerForNotifications()

        self.retryConfig.reconnectDelay = .noDelay

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
