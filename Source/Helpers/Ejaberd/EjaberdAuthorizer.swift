//
//  EjaberdAuthorizer.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 02.01.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import XMPPFrameworkSwift

public class EjaberdAuthorizer: NSObject, XMPPStreamDelegate {
    private let stream: XMPPStream
    private let mutex: Mutex = Mutex()

    private var error: Error?

    private let delegateQueue = DispatchQueue(label: "Twilio")

    override init() {
        self.stream = XMPPStream()

        super.init()

        try! Ejaberd.configure(stream: self.stream,
                               with: "admin",
                               delegate: self,
                               queue: self.delegateQueue)

        try! self.mutex.lock()
    }

    func register(identity: String) throws {
        let username = DDXMLElement(name: "username", stringValue: identity)
        let password = DDXMLElement(name: "password", stringValue: "1111")

        if !self.stream.isConnected {
            try self.stream.connect(withTimeout: XMPPStreamTimeoutNone)
            try self.mutex.lock()
        }

        Log.debug("Trying to register")
        try self.stream.register(with: [username, password])

        if let error = self.error {
            throw error
        }

        try self.mutex.lock()
    }
}

public extension EjaberdAuthorizer {
    func xmppStreamWillConnect(_ sender: XMPPStream) {
        Log.debug("EjaberdAuthenticator: Connecting...")
    }

    func xmppStreamDidConnect(_ stream: XMPPStream) {
        Log.debug("EjaberdAuthenticator: Connected")
        print("supportsInBandRegistration: \(self.stream.supportsInBandRegistration)")

        do {
            try self.mutex.unlock()
        }
        catch {
            Log.error("EjaberdAuthenticator: \(error)")
        }
    }

    func xmppStreamConnectDidTimeout(_ sender: XMPPStream) {
        // TODO: implement me
    }

    func xmppStreamDidDisconnect(_ sender: XMPPStream, withError error: Error?) {
        // TODO: implement me
    }

    func xmppStreamDidRegister(_ sender: XMPPStream) {
        Log.debug("EjaberdAuthenticator: Registered")

        do {
            try self.mutex.unlock()
        }
        catch {
            Log.error("EjaberdAuthenticator: \(error)")
        }
    }

    func xmppStream(_ sender: XMPPStream, didNotRegister error: DDXMLElement) {
        Log.error("EjaberdAuthenticator: Registration failed - \(error)")

        self.error = NSError()

        do {
            try self.mutex.unlock()
        }
        catch {
            Log.error("EjaberdAuthenticator: \(error)")
        }
    }
}
