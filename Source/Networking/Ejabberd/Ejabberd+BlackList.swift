//
//  Ejabberd+BlackList.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 5/12/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import XMPPFrameworkSwift

extension Ejabberd {
    func block(user: String, completion: @escaping (Error?) -> Void) {
        do {
            guard self.state == .connected else {
                completion()
                return
            }

            let userJID = try Ejabberd.setupJid(with: user)

            try self.completionQueue.first { $0.type == .blockUnblock }?.mutex.lock()

            let completionItem = try CompletionQueueItem(type: .blockUnblock, completion: completion)
            self.completionQueue.append(completionItem)

            self.blocking.blockJID(userJID)
        }
        catch {
            completion(error)
        }
    }

    func unblock(user: String, completion: @escaping (Error?) -> Void) {
        do {
            let userJID = try Ejabberd.setupJid(with: user)

            try self.completionQueue.first { $0.type == .blockUnblock }?.mutex.lock()

            let completionItem = try CompletionQueueItem(type: .blockUnblock, completion: completion)
            self.completionQueue.append(completionItem)

            self.blocking.unblockJID(userJID)
        }
        catch {
            completion(error)
        }
    }
}

extension Ejabberd: XMPPBlockingDelegate {
    public func xmppBlocking(_ sender: XMPPBlocking!, didBlockJID xmppJID: XMPPJID!) {
        self.queryCompleted(type: .blockUnblock, error: nil)
    }

    public func xmppBlocking(_ sender: XMPPBlocking!, didNotBlockJID xmppJID: XMPPJID!, error: Any!) {
        let error = error as? Error ?? EjabberdError.blockingActionFailed

        self.queryCompleted(type: .blockUnblock, error: error)
    }

    public func xmppBlocking(_ sender: XMPPBlocking!, didUnblockJID xmppJID: XMPPJID!) {
        self.queryCompleted(type: .blockUnblock, error: nil)
    }

    public func xmppBlocking(_ sender: XMPPBlocking!, didNotUnblockJID xmppJID: XMPPJID!, error: Any!) {
        let error = error as? Error ?? EjabberdError.blockingActionFailed

        self.queryCompleted(type: .blockUnblock, error: error)
    }

    public func xmppBlocking(_ sender: XMPPBlocking!, didReceivedBlockingList blockingList: [Any]!) {
        for item in blockingList {
            guard
                let jidString = item as? String,
                let jid = XMPPJID(string: jidString),
                let name = jid.user,
                let channel = Storage.shared.getSingleChannel(with: name)
            else {
                continue
            }

            if !channel.blocked {
                try? Storage.shared.block(channel: channel)
            }
        }
    }
}
