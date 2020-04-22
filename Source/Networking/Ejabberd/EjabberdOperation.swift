//
//  EjabberdOperation.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 21.04.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import XMPPFrameworkSwift

enum EjabberdOperationState {
    case new
    case inProgress
    case sent
    case failed
}

class EjabberdOperation: Operation {
    let message: XMPPMessage
    let stream: XMPPStream
    let delegateQueue = DispatchQueue(label: "EjabberdOperation")
    var state: EjabberdOperationState = .new

    init(message: XMPPMessage, stream: XMPPStream) {
        self.message = message
        self.stream = stream
    }

    override func main() {
        self.stream.addDelegate(self, delegateQueue: self.delegateQueue)

        while true {
            if self.isCancelled {
                return
            }

            switch self.state {
            case .new, .failed:
                if self.stream.isAuthenticated {
                    self.state = .inProgress
                    self.stream.send(message)
                }

            case .inProgress:
                break

            case .sent:
                return
            }
        }
    }
}

extension EjabberdOperation: XMPPStreamDelegate {
    private func isMy(message: XMPPMessage) -> Bool {
        guard
            let messageId = message.elementID,
            let ourMessageId = self.message.elementID,
            messageId == ourMessageId
        else {
            return false
        }

        return true
    }

    func xmppStream(_ sender: XMPPStream, didSend message: XMPPMessage) {
        if !self.isMy(message: message) {
            return
        }

        self.state = .sent
    }

    func xmppStream(_ sender: XMPPStream, didFailToSend message: XMPPMessage, error: Error) {
        if !self.isMy(message: message) {
            return
        }

        Log.error(error, message: "Ejabberd: message failed to send")

        self.state = .failed
    }
}
