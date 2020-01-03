//
//  Ejabberd+delegate.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 03.01.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import XMPPFrameworkSwift

extension Ejabberd: XMPPStreamDelegate {
    func xmppStreamWillConnect(_ sender: XMPPStream) {
        Log.debug("Ejabberd: Connecting...")
    }

    func xmppStreamDidConnect(_ stream: XMPPStream) {
        Log.debug("Ejabberd: Connected")

        do {
            try self.mutex.unlock()
        }
        catch {
            Log.error("Ejabberd: \(error)")
        }
    }

    func xmppStreamConnectDidTimeout(_ sender: XMPPStream) {
        // TODO: implement me
        Log.debug("Ejabberd: Connect reached timeout")
    }

    func xmppStreamDidDisconnect(_ sender: XMPPStream, withError error: Error?) {
        // TODO: implement me
        Log.debug("Ejabberd: Disconected")
    }

    func xmppStream(_ sender: XMPPStream, didReceive message: XMPPMessage) {
        print("Message received")

        self.queue.async {
            do {
                let author = try message.getAuthor()
                let encryptedMessage = try EncryptedMessage.import(message)

                guard let message = try MessageProcessor.process(encryptedMessage, from: author),
                    let currentChannel = CoreData.shared.currentChannel,
                    currentChannel.name == author else {
                        // TODO: Check if needed
                        return Notifications.post(.chatListUpdated)
                }

                Notifications.post(message: message)
            } catch {
                Log.error("\(error)")
            }
        }
    }
}
