//
//  Ejabberd.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 27.12.2019.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import XMPPFrameworkSwift

class Ejabberd: NSObject {
    private(set) static var shared: Ejabberd = Ejabberd()

    private let stream: XMPPStream = XMPPStream()

    // FIXME
    private let delegateQueue = DispatchQueue(label: "EjabberdDelegate")

    internal var error: Error?
    internal let mutex: Mutex = Mutex()
    internal let queue = DispatchQueue(label: "Ejabberd")

    override init() {
        super.init()

        try! self.mutex.lock()
    }

    public func connect(identity: String) throws {
        guard !self.stream.isConnected else {
            return
        }

        try Ejabberd.configure(stream: self.stream,
                              with: identity,
                              delegate: self,
                              queue: self.delegateQueue)

        // FIME: Timeout
        try self.stream.connect(withTimeout: XMPPStreamTimeoutNone)
        try self.mutex.lock()

        if let error = self.error {
            throw error
        }
    }

    public static func configure(stream: XMPPStream,
                                 with username: String,
                                 delegate: XMPPStreamDelegate,
                                 queue: DispatchQueue) throws {
        stream.hostName = URLConstants.EjabberdHost
        stream.hostPort = URLConstants.EjabberdHostPort

        let jidString = "\(username)@\(URLConstants.EjabberdHost)"

        guard let jid = XMPPJID(string: jidString) else {
            throw NSError()
        }

        stream.myJID = jid
        stream.startTLSPolicy = .allowed
        stream.addDelegate(delegate, delegateQueue: queue)
    }
}
