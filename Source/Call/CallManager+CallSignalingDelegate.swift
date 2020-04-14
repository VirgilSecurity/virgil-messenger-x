//
//  CallManager+CallSignalingDelegate.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 08.04.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

extension CallManager {
    func sendSignalingMessage(callOffer: NetworkMessage.CallOffer, to call: Call, completion: @escaping (_ error: Error?) -> Void) {
        let opponent = call.opponent
        guard let opponentChannel = Storage.shared.getSingleChannel(with: opponent) else {
            completion(CallManagerContractError.noChannel)
            return
        }

        self.messageSender.send(callOffer: callOffer, date: Date(), channel: opponentChannel) { (error) in
            guard let error = error else {
                completion(nil)
                return
            }

            Log.error(error, message: "Failed to send 'call offer' signaling message")
            completion(CallManagerError.signalingFailed)
        }
    }

    func sendSignalingMessage(callAnswer: NetworkMessage.CallAnswer, to call: Call, completion: @escaping (_ error: Error?) -> Void) {
        let opponent = call.opponent
        guard let opponentChannel = Storage.shared.getSingleChannel(with: opponent) else {
            completion(CallManagerContractError.noChannel)
            return
        }

        self.messageSender.send(callAnswer: callAnswer, date: Date(), channel: opponentChannel) { (error) in
            guard let error = error else {
                completion(nil)
                return
            }

            Log.error(error, message: "Failed to send 'call answer' signaling message")
            completion(CallManagerError.signalingFailed)
        }
    }

    func sendSignalingMessage(callUpdate: NetworkMessage.CallUpdate, to call: Call, completion: @escaping (_ error: Error?) -> Void) {
        let opponent = call.opponent
        guard let opponentChannel = Storage.shared.getSingleChannel(with: opponent) else {
            completion(CallManagerContractError.noChannel)
            return
        }

        self.messageSender.send(callUpdate: callUpdate, date: Date(), channel: opponentChannel) { (error) in
            guard let error = error else {
                completion(nil)
                return
            }

            Log.error(error, message: "Failed to send 'call update' signaling message")
            completion(CallManagerError.signalingFailed)
        }
    }

    func sendSignalingMessage(iceCandidate: NetworkMessage.IceCandidate, to call: Call, completion: @escaping (_ error: Error?) -> Void) {
        let opponent = call.opponent

        guard let opponentChannel = Storage.shared.getSingleChannel(with: opponent) else {
            return
        }

        self.messageSender.send(iceCandidate: iceCandidate, date: Date(), channel: opponentChannel) { (error) in
            guard let error = error else {
                completion(nil)
                return
            }

            Log.error(error, message: "Failed to send 'ice candidate' signaling message")
            completion(CallManagerError.signalingFailed)
        }
    }
}

extension CallManager: CallSignalingDelegate {
    public func call(_ call: Call, didCreateOffer offer: NetworkMessage.CallOffer) {
        self.sendSignalingMessage(callOffer: offer, to: call) { (error) in
            if let error = error {
                self.didFailCall(call, error)
            }
        }
    }

    public func call(_ call: Call, didCreateAnswer answer: NetworkMessage.CallAnswer) {
        self.sendSignalingMessage(callAnswer: answer, to: call) { (error) in
            if let error = error {
                self.didFailCall(call, error)
            }
        }
    }

    public func call(_ call: Call, didCreateIceCandidate iceCandidate: NetworkMessage.IceCandidate) {
        self.sendSignalingMessage(iceCandidate: iceCandidate, to: call) { (error) in
            if let error = error {
                self.didFailCall(call, error)
            }
        }
    }

    public func call(_ call: Call, didCreateUpdate update: NetworkMessage.CallUpdate) {
        self.sendSignalingMessage(callUpdate: update, to: call) { error in
            if let error = error {
                self.didFail(error)
            }
        }
    }

    public func call(_ call: Call, didFail error: Error) {
        let callUpdate = NetworkMessage.CallUpdate(callUUID: call.uuid, action: .end)

        self.delegate?.callManager(self, didFailCall: call, error: error)
        self.removeCall(call)

        self.sendSignalingMessage(callUpdate: callUpdate, to: call) { error in
            if let error = error {
                self.didFail(error)
            }
        }
    }
}
