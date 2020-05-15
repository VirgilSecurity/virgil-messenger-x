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
    case loadAudioAssetFailed
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

private enum CallStatusPlayback: String {
    case none
    case initiateCall
    case calling
    case connectionLost
    case endCall
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
    private let audioControlQueue = DispatchQueue(label: "CallManager.AudioControlQueue")

    // MARK: Playback properties
    private var beepAudioPlayer: AVAudioPlayer?
    private var callInitiateAudioPlayer: AVAudioPlayer?
    private var callEndAudioPlayer: AVAudioPlayer?
    private var connectionLostPlayer: AVAudioPlayer?
    private var requestedCallStatusPlayback: CallStatusPlayback = .none
    private var currentCallStatusPlayback: CallStatusPlayback = .none

    // MARK: Delegate
    weak var delegate: CallManagerDelegate?

    // MARK: Calls properties
    private(set) var account: Storage.Account?

    private(set) var calls = Set<Call>()

    // MARK: - Init / Reset
    public override init() {
        super.init()

        self.callProvider.setDelegate(self, queue: callProviderQueue)
        self.configureAudioResources()
    }

    public func set(account: Storage.Account) {
        self.account = account
    }

    public func resetAccount() {
        self.account = nil

        self.endAllCalls()
    }

    private func setupPlayer(assetName: String) -> AVAudioPlayer? {
        var player: AVAudioPlayer?

        do {
            guard let dataAsset = NSDataAsset(name: assetName) else {
                throw CallManagerError.loadAudioAssetFailed
            }

            player = try AVAudioPlayer(data: dataAsset.data, fileTypeHint: AVFileType.wav.rawValue)
            player?.delegate = self
            player?.prepareToPlay()
        }
        catch {
            Log.error(error, message: "Setting up player for \(assetName) call sound failed")
        }

        return player
    }

    private func configureAudioResources() {
        self.beepAudioPlayer = self.setupPlayer(assetName: "audio-short-dial")
        self.beepAudioPlayer?.numberOfLoops = -1

        self.callInitiateAudioPlayer = self.setupPlayer(assetName: "audio-initiating-secure-call")
        self.callEndAudioPlayer = self.setupPlayer(assetName: "audio-secure-call-ended")
        self.connectionLostPlayer = self.setupPlayer(assetName: "audio-connection-lost")
    }

    // MARK: Calls Management
    public func startOutgoingCall(to callee: String) {
        do {
            try self.configureAudioSession()

            self.requestCallStatusPlayback(.initiateCall)

            self.requestSystemStartOutgoingCall(to: callee) { error in
                if let error = error {
                    self.delegate?.callManager(self, didFail: error)
                }
            }
        }
        catch {
            Log.error(error, message: "Failed to configure audio session.")
            self.didFail(CallManagerError.configureFailed)
        }
    }

    public func startIncomingCall(from callOffer: NetworkMessage.CallOffer, pushKitCompletion: @escaping () -> Void) {

        let callUUID = callOffer.callUUID
        let caller = callOffer.caller

        if self.findCall(with: callUUID) != nil {
            Log.debug("Call with id \(callUUID.uuidString) was already added.")
            self.requestSystemDummyIncomingCall(pushKitCompletion: pushKitCompletion)
            return
        }

        self.requestSystemStartIncomingCall(from: caller, withId: callUUID) { error in
            defer {
                pushKitCompletion()
            }

            if let error = error {
                Log.debug("Incomming call with id \(callUUID.uuidString) was not started.")
                self.didFail(error)
            }

            self.callProviderQueue.async {
                do {
                    guard let account = self.account else {
                        throw CallManagerContractError.noAccount
                    }

                    try self.configureAudioSession()

                    let call = IncomingCall(from: callOffer, to: account.identity, signalingTo: self)

                    call.start { error in
                        guard let error = error else {
                            self.addCall(call)
                            self.updateRemoteCall(call, withAction: .received)
                            return
                        }

                        self.requestSystemEndCall(uuid: callUUID) { _ in }
                        self.didFail(error)
                    }
                }
                catch {
                    self.requestSystemEndCall(uuid: callUUID) { _ in }
                    self.didFail(error)
                }
            }
        }
    }

    public func startDummyIncomingCall(pushKitCompletion: @escaping () -> Void) {
        self.requestSystemDummyIncomingCall(pushKitCompletion: pushKitCompletion)
    }

    public func endCall(_ call: Call) {
        if self.findCall(with: call.uuid) == nil {
            return
        }

        self.requestCallStatusPlayback(.endCall)

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
            self.requestCallStatusPlayback(.endCall)

            self.requestSystemEndCall(call) { error in
                if let error = error {
                    self.didFailCall(call, error)
                }
            }

        case .received:
            self.requestCallStatusPlayback(.calling)

            if let outgoingCall = call as? OutgoingCall {
                outgoingCall.remoteDidAcceptCall()
            }
        }
    }

    func hold(on isOnHold: Bool) {
        self.calls.forEach { $0.hold(on: isOnHold) }
    }

    func addCall(_ call: Call) {
        call.addObserver(self)
        self.calls.insert(call)
        self.delegate?.callManager(self, didAddCall: call)
    }

    func removeCall(_ call: Call) {
        call.removeObserver(self)
        self.calls.remove(call)
        self.delegate?.callManager(self, didRemoveCall: call)
    }

    func findCall(with uuid: UUID) -> Call? {
        self.calls.first { $0.uuid == uuid }
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

        self.processRequestedCallStatusPlayback()

        Log.debug("CallManager: did activate audio session.")
    }

    func deactivateAudioSession(_ session: AVAudioSession) {
        Log.debug("CallManager: will deactivate audio session.")

        self.stopBeepCallStatusPlayback()

        self.audioSession.audioSessionDidDeactivate(session)

        Log.debug("CallManager: did deactivate audio session.")
    }

    // MARK: Playback control
    private func requestCallStatusPlayback(_ status: CallStatusPlayback) {
        self.audioControlQueue.async {
            self.requestedCallStatusPlayback = status
        }

        self.processRequestedCallStatusPlayback()
    }

    private func processRequestedCallStatusPlayback() {
        self.audioControlQueue.async {
            guard self.audioSession.isAudioEnabled else {
                return
            }

            switch self.currentCallStatusPlayback {
            case .calling:
                self.beepAudioPlayer?.stop()

            case .connectionLost, .endCall, .initiateCall:
                return

            case .none:
                break
            }

            switch self.requestedCallStatusPlayback {
            case .none:
                break

            case .initiateCall:
                self.callInitiateAudioPlayer?.play()

            case .calling:
                self.beepAudioPlayer?.play()

            case .connectionLost:
                self.connectionLostPlayer?.play()

            case .endCall:
                self.callEndAudioPlayer?.play()
            }

            self.currentCallStatusPlayback = self.requestedCallStatusPlayback
            self.requestedCallStatusPlayback = .none
        }
    }

    private func stopBeepCallStatusPlayback() {
        self.audioControlQueue.async {
            self.beepAudioPlayer?.stop()

            self.currentCallStatusPlayback = .none
        }
    }
}

extension CallManager: AVAudioPlayerDelegate {
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.currentCallStatusPlayback = .none
        self.processRequestedCallStatusPlayback()
    }
}

extension CallManager: CallDelegate {
    public func call(_ call: Call, didChangeConnectionStatus newConnectionStatus: CallConnectionStatus) {
        switch newConnectionStatus {
        case .connected:
            self.stopBeepCallStatusPlayback()

        case .disconnected:
            self.requestCallStatusPlayback(.connectionLost)

        default:
            break;
        }
    }
}
