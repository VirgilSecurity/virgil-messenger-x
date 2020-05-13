//
//  Ejabberd+BlackList.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 5/12/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import XMPPFrameworkSwift

extension Ejabberd {
    func blacklist() throws -> [XMPPJID] {
        // FIXME
        guard let result = self.blocking.blockingList() as? [XMPPJID] else {
            throw NSError()
        }

        return result
    }

    func block(user: String) throws {
        let userJID = try Ejabberd.setupJid(with: user)

        self.blocking.blockJID(userJID)
    }
}

extension Ejabberd: XMPPBlockingDelegate {
    public func xmppBlocking(_ sender: XMPPBlocking!, didBlockJID xmppJID: XMPPJID!) {
        // FIXME: Implement me
    }

    public func xmppBlocking(_ sender: XMPPBlocking!, didNotBlockJID xmppJID: XMPPJID!, error: Any!) {
        // FIXME: Implement me
    }

    public func xmppBlocking(_ sender: XMPPBlocking!, didUnblockJID xmppJID: XMPPJID!) {
        // FIXME: Implement me
    }

    public func xmppBlocking(_ sender: XMPPBlocking!, didNotUnblockJID xmppJID: XMPPJID!, error: Any!) {
         // FIXME: Implement me
    }
}
