//
//  Ejaberd.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 27.12.2019.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import XMPPFrameworkSwift

class Ejaberd {
    private(set) static var shared: Ejaberd!

    private let stream: XMPPStream = XMPPStream()

    public static func configure(stream: XMPPStream,
                                 with username: String,
                                 delegate: XMPPStreamDelegate,
                                 queue: DispatchQueue) throws {
        stream.hostName = URLConstants.ejaberdHost
        stream.hostPort = URLConstants.ejaberdHostPort

        let jidString = "\(username)@\(URLConstants.ejaberdHost)"

        guard let jid = XMPPJID(string: jidString) else {
            throw NSError()
        }

        stream.myJID = jid

        stream.startTLSPolicy = .allowed

        stream.addDelegate(delegate, delegateQueue: queue)
    }
}
