//
//  CallManager.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 04.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import WebRTC
import CallKit

public enum CallManagerError: String, Error {
    case signalingFailed
    case noActiveCall
    case callKitFailed
    case configureFailed
}

public enum CallManagerContractError: String, Error {
    case noChannel
    case noAccount
}

public protocol CallManagerDelegate: class {
    func callManager(_ callManager: CallManager, didAddCall call: Call)
    func callManager(_ callManager: CallManager, didRemoveCall call: Call)
    func callManager(_ callManager: CallManager, didFail error: Error)
    func callManager(_ callManager: CallManager, didFailCall call: Call, error: Error)
}

public class CallManager: NSObject {

    // MARK: Singleton
    private(set) static var shared: CallManager = CallManager()

    // MARK: Helper properties
    let callProvider: CXProvider = CallManager.createCallKitProvider()
    let callController = CXCallController()
    let audioSession = RTCAudioSession.sharedInstance()
    let messageSender: MessageSender = MessageSender()

    private let callProviderQueue = DispatchQueue(label: "CallManager.CallProviderQueue")

    // MARK: Delegate
    weak var delegate: CallManagerDelegate?

    // MARK: Calls properties
    private(set) var account: Storage.Account?

    private var calls = Set<Call>()

    // MARK: - Init / Reset
    public override init() {
        super.init()

        self.callProvider.setDelegate(self, queue: callProviderQueue)
        
    }

    public func set(account: Storage.Account) {
        self.account = account
    }

    public func resetAccount() {
        self.account = nil

        self.endAllCalls()
    }

    // MARK: Calls Management
    public func startOutgoingCall(to callee: String) {
        do {
            try self.configureAudioSession()
        } catch {
            Log.error(error, message: "Failed to configure audio session.")
            self.didFail(CallManagerError.configureFailed)
            return
        }

        self.requestSystemStartOutgoingCall(to: callee) { error in
            if let error = error {
                self.delegate?.callManager(self, didFail: error)
            }
        }
    }

    public func startIncomingCall(from callOffer: NetworkMessage.CallOffer) {
        guard let account = self.account else {
            self.didFail(CallManagerContractError.noAccount)
            return
        }

        let callUUID = callOffer.callUUID
        let caller = callOffer.caller

        if self.findCall(with: callUUID) != nil {
            Log.debug("Call with id \(callUUID.uuidString) was already added")
            return
        }

        do {
            try self.configureAudioSession()
        } catch {
            Log.error(error, message: "Failed to configure audio session.")
            self.didFail(CallManagerError.configureFailed)
            return
        }

        self.requestSystemStartIncomingCall(from: caller, withId: callUUID) { error in
            guard let error = error else {
                let call = IncomingCall(from: callOffer, to: account.identity, signalingTo: self)

                call.start { error in
                    guard let error = error else {
                        self.addCall(call)
                        self.updateRemoteCall(call, withAction: .received)
                        return
                    }

                    self.didFail(error)
                }

                return
            }

            Log.error(error, message: "Incomming call was not started with id \(callUUID.uuidString)")
        }
    }

    public func endCall(_ call: Call) {
        self.requestSystemEndCall(call) { error in
            if let error = error {
                self.didFailCall(call, error)
            }
        }
    }

    func endAllCalls() {
        self.calls.forEach { call in
            call.end()
        }

        self.calls.removeAll()
    }

    func processIceCandidate(_ iceCandidate: NetworkMessage.IceCandidate) {
        let callUUID = iceCandidate.callUUID

        guard let call = self.findCall(with: callUUID) else {
            return
        }

        call.addRemoteIceCandidate(iceCandidate)
    }

    func processCallAnswer(_ callAnswer: NetworkMessage.CallAnswer) {
        let callUUID = callAnswer.callUUID

        guard
            let call = self.findCall(with: callUUID),
            let outgoingCall = call as? OutgoingCall
        else {
            return
        }

        outgoingCall.accept(callAnswer)
    }

    func processCallUpdate(_ callUpdate: NetworkMessage.CallUpdate) {
        let callUUID = callUpdate.callUUID

        guard let call = self.findCall(with: callUUID) else {
            return
        }

        let action = callUpdate.action
        switch action {
        case .end:
            self.requestSystemEndCall(call) { error in
                if let error = error {
                    self.didFailCall(call, error)
                }
            }

        case .received:
            if let outgoingCall = call as? OutgoingCall {
                outgoingCall.remoteDidAcceptCall()
            }
        }
    }

    func addCall(_ call: Call) {
        self.calls.insert(call)
        self.delegate?.callManager(self, didAddCall: call)
    }

    func removeCall(_ call: Call) {
        self.calls.remove(call)
        self.delegate?.callManager(self, didRemoveCall: call)
    }

    func findCall(with uuid: UUID) -> Call? {
        let call = self.calls.first { $0.uuid == uuid }
        return call
    }

    // MARK: Events
    public func didFail(_ error: Error) {
        Log.error(error, message: "CallManager met error")

        self.delegate?.callManager(self, didFail: error)
    }

    public func didFailCall(_ call: Call, _ error: Error) {
        Log.error(error, message: "CallManager met error with a call \(call)")

        self.delegate?.callManager(self, didFailCall: call, error: error)
    }

    // MARK: Notifications to the remote call
    func updateRemoteCall(_ call: Call, withAction action: CallUpdateAction) {
        let callUpdate = NetworkMessage.CallUpdate(callUUID: call.uuid, action: action)
        self.call(call, didCreateUpdate: callUpdate)
    }

    // MARK: Voice Configuration
    func configureAudioSession() throws {
        Log.debug("CallManager: will configure audio session.")
        self.audioSession.lockForConfiguration()

        try self.audioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
        try self.audioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
        self.audioSession.useManualAudio = true
        self.audioSession.isAudioEnabled = false

        Log.debug("CallManager: did configure audio session.")
        self.audioSession.unlockForConfiguration()
    }

    func restoreAudioSessionConfig() {
        Log.debug("CallManager: will restore initial configuration.")
        self.audioSession.lockForConfiguration()

        do {
            try self.audioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
            try self.audioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
            self.audioSession.useManualAudio = false
            self.audioSession.isAudioEnabled = false
        }
        catch {
            Log.error(error, message: "Failed to restore audio session configuration.")
        }

        Log.debug("CallManager: did restore audio session.")
        self.audioSession.unlockForConfiguration()
    }

    func activateAudioSession(_ session: AVAudioSession) {
        Log.debug("CallManager: will activate audio session.")

        self.audioSession.audioSessionDidActivate(session)
        self.audioSession.isAudioEnabled = true

        Log.debug("CallManager: did activate audio session.")
    }

    func deactivateAudioSession(_ session: AVAudioSession) {
        Log.debug("CallManager: will deactivate audio session.")
        self.audioSession.audioSessionDidDeactivate(session)
        Log.debug("CallManager: did deactivate audio session.")
    }
}
