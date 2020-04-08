//
//  WebRTCChannel.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 04.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import WebRTC
import CallKit

private let kIceServers = ["stun:stun.l.google.com:19302",
                  "stun:stun1.l.google.com:19302",
                  "stun:stun2.l.google.com:19302",
                  "stun:stun3.l.google.com:19302",
                  "stun:stun4.l.google.com:19302"]

public protocol CallManagerObserver: class {
    func callManager(_ callManager: CallManager, didChange newConnectionStatus: CallManager.ConnectionStatus)
}

extension CallManagerObserver {
    func callManager(_ callManager: CallManager, didChange newConnectionStatus: CallManager.ConnectionStatus) {}
}

public enum CallManagerError: String, Error {
    case configurationFailed
    case signalingFailed
    case connectionFailed
}

public enum CallManagerContractError: String, Error {
    case preconditionViolated
    case noChannel
    case noAccount
    case noPeerConnection
    case noCallOffer
}

public class CallManager: NSObject {

    // MARK: - Public types
    public enum CallDirection: String {
        case none
        case incoming
        case outgoing
    }

    public enum ConnectionStatus: Equatable {
        case none // is not notifiable
        case new
        case waitingForAnswer // can be both an incomming and an outgoing calls
        case rejected // call was rajected
        case acceptAnswer // when user press accept call button
        case negotiating // esteblish connection parameters
        case connected // connection stable
        case disconnected // temporary disconnected
        case closed // connection was closed by one of the parties
        case failed(Error) // connection failed after being disconnected

        public static func == (lhs: CallManager.ConnectionStatus, rhs: CallManager.ConnectionStatus) -> Bool {
            switch (lhs, rhs) {
            case (.none, .none),
                 (.new, .new),
                 (.waitingForAnswer, .waitingForAnswer),
                 (.rejected, .rejected),
                 (.negotiating, .negotiating),
                 (.connected, .connected),
                 (.closed, .closed),
                 (.failed, .failed):
              return true

            default:
              return false
            }
        }
    }

    // MARK: - Singleton
    private(set) static var shared: CallManager = CallManager()

    // MARK: - Inner state
    private static let factory: RTCPeerConnectionFactory = RTCPeerConnectionFactory()

    private static let callKitProvider: CXProvider = CallManager.createCallKitProvider()

    private let messageSender: MessageSender

    private var peerConnection: RTCPeerConnection?

    private var account: Storage.Account?

    private var channel: Storage.Channel?

    private(set) var callDirection: CallDirection = .none

    var connectionStatus: ConnectionStatus = .none {
        didSet {
            if connectionStatus != .none {
                self.notifyObservers { (observer) in
                    observer.callManager(self, didChange: connectionStatus)
                }
            }
        }
    }

    public var callIdentifier: String {
        if let channel = self.channel, self.callDirection != .none {
            return channel.name
        } else {
            return "<unexpected>"
        }
    }

    // MARK: - Observers / Notifications
    private struct Observation {
        weak var observer: CallManagerObserver?
    }

    private var observations = [ObjectIdentifier: Observation]()

    public func addObserver(_ observer: CallManagerObserver) {
        let observerId = ObjectIdentifier(observer)
        self.observations[observerId] = Observation(observer: observer)
    }

    public func removeObserver(_ observer: CallManagerObserver) {
        let observerId = ObjectIdentifier(observer)
        self.observations.removeValue(forKey: observerId)
    }

    public func removeAllObservers() {
        self.observations.removeAll()
    }

    private func notifyObservers(notify: (CallManagerObserver) -> Void) {
        for (observerId, observation) in self.observations {
            // Cleanup
            guard let observer = observation.observer else {
                observations.removeValue(forKey: observerId)
                continue
            }
            notify(observer)
        }
    }

    // MARK: - Init / Reset
    override private init() {
        self.messageSender = MessageSender()
        super.init()
        self.cleanup()
    }

    private func cleanup() {
        self.peerConnection?.delegate = nil
        self.peerConnection?.close()
        self.peerConnection = nil
        self.callDirection = .none
        self.connectionStatus = .none
        self.channel = nil
    }

    public func set(account: Storage.Account) {
        self.account = account
        self.channel = nil
        self.cleanup()
    }

    public func resetAccount() {
        self.account = nil
        self.cleanup()
    }

    // MARK: - Call management
    func startOutgoingCall(in channel: Storage.Channel) {
        self.cleanup()
        self.callDirection = .outgoing
        self.connectionStatus = .new
        self.channel = channel

        let constrains = RTCMediaConstraints(mandatoryConstraints:
                [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue], optionalConstraints: nil)

        do {
            self.peerConnection = try Self.createPeerConnection(delegate: self)
        } catch {
            self.connectionStatus = .failed(CallManagerError.configurationFailed)
            return
        }

        self.peerConnection!.offer(for: constrains) { sdp, error in
            guard let sdp = sdp else {
                self.connectionStatus = .failed(CallManagerError.configurationFailed)
                return
            }

            self.peerConnection!.setLocalDescription(sdp) { error in
                guard let error = error else {
                    self.sendSignalingMessage(offer: sdp) { error in
                        guard let error = error else {
                            self.connectionStatus = .waitingForAnswer
                            return
                        }

                        self.connectionStatus = .failed(error)
                    }
                    return
                }

                Log.error(error, message: "Failed to set local description")
                self.connectionStatus = .failed(CallManagerError.configurationFailed)
            }
        }
    }

    func startIncommingCall(callOffer: NetworkMessage.CallOffer, in channel: Storage.Channel) {
        self.cleanup()
        self.callDirection = .incoming
        self.connectionStatus = .new
        self.channel = channel

        do {
            self.peerConnection = try Self.createPeerConnection(delegate: self)
        } catch {
            self.connectionStatus = .failed(CallManagerError.configurationFailed)
            return
        }

        self.peerConnection!.setRemoteDescription(callOffer.rtcSessionDescription) { error in
            guard let error = error else {
                self.connectionStatus = .waitingForAnswer
                return
            }

            Log.error(error, message: "Failed to set an offer session description as remote session description")
            self.connectionStatus = .failed(CallManagerError.configurationFailed)
        }
    }

    func rejectCall() {
        if (self.callDirection != .incoming) || (self.connectionStatus != .waitingForAnswer) {
            self.connectionStatus = .failed(CallManagerContractError.preconditionViolated)
            return
        }

        if self.peerConnection == nil {
            self.connectionStatus = .failed(CallManagerContractError.noPeerConnection)
            return
        }

        self.sendSignalingMessageCallRejectedAnswer { (error) in
            guard let error = error else {
                self.connectionStatus = .rejected
                self.cleanup()
                return
            }
            Log.error(error, message: "Failed to send call rejection")
            self.connectionStatus = .failed(CallManagerError.signalingFailed)
        }
    }

    func acceptCall() {
        if (self.callDirection != .incoming) || (self.connectionStatus != .waitingForAnswer) {
            self.connectionStatus = .failed(CallManagerContractError.preconditionViolated)
            return
        }

        guard let peerConnection = self.peerConnection else {
            self.connectionStatus = .failed(CallManagerContractError.noPeerConnection)
            return
        }

        self.connectionStatus = .acceptAnswer

        let constrains = RTCMediaConstraints(mandatoryConstraints: [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue],
                                             optionalConstraints: nil)

        peerConnection.answer(for: constrains) { localSDP, error in
            guard let answerSdp = localSDP else {
                if let error = error {
                    Log.error(error, message: "Failed to create an answer session description")
                }
                self.connectionStatus = .failed(CallManagerError.configurationFailed)
                return
            }

            peerConnection.setLocalDescription(answerSdp) { error in
                guard let error = error else {
                    self.sendSignalingMessage(callAcceptedAnswer: answerSdp) { (error) in
                        guard let error = error else {
                            self.connectionStatus = .negotiating
                            return
                        }

                        self.connectionStatus = .failed(error)
                    }
                    return
                }

                Log.error(error, message: "Failed to set an answer session description as local session description")
                self.connectionStatus = .failed(CallManagerError.configurationFailed)
            }
        }
    }

    func processCallAcceptedAnswer(_ callAcceptedAnswer: NetworkMessage.CallAcceptedAnswer) {
        if (self.callDirection != .outgoing) || (self.connectionStatus != .waitingForAnswer) {
            self.connectionStatus = .failed(CallManagerContractError.preconditionViolated)
            return
        }

        guard let peerConnection = self.peerConnection else {
            self.connectionStatus = .failed(CallManagerContractError.noPeerConnection)
            return
        }

        self.connectionStatus = .acceptAnswer

        let callAnswer = callAcceptedAnswer.rtcSessionDescription
        peerConnection.setRemoteDescription(callAnswer) { (error) in
            if let error = error {
                Log.error(error, message: "Failed to set an answer session description as remote session description")
                self.connectionStatus = .failed(CallManagerError.configurationFailed)
            }
        }
    }

    func processCallRejectedAnswer(_ callRejectedAnswer: NetworkMessage.CallRejectedAnswer) {
        if (self.callDirection != .outgoing) || (self.connectionStatus != .waitingForAnswer) {
            self.connectionStatus = .failed(CallManagerContractError.preconditionViolated)
            return
        }

        if self.peerConnection == nil {
            self.connectionStatus = .failed(CallManagerContractError.noPeerConnection)
            return
        }

        self.connectionStatus = .rejected
        self.cleanup()
    }

    func addIceCandidate(_ iceCandidate: NetworkMessage.IceCandidate) {
        switch self.connectionStatus {
        case .new, .acceptAnswer, .connected, .negotiating, .waitingForAnswer:
            break
        default:
            self.connectionStatus = .failed(CallManagerContractError.preconditionViolated)
            return
        }

        guard let peerConnection = self.peerConnection else {
            self.connectionStatus = .failed(CallManagerContractError.noPeerConnection)
            return
        }

        let candidate = iceCandidate.rtcIceCandidate

        Log.debug("WebRTC: will add remote candidate:\n    sdp = \(candidate.sdp)")

        peerConnection.add(candidate)
    }

    func endCall() {
        self.peerConnection?.close()
        self.cleanup()

        // FIXME: Send "EndCall" message
    }

    private static func createPeerConnection(delegate: RTCPeerConnectionDelegate?) throws -> RTCPeerConnection {
        // Basic configuration
        let rtcConfig = RTCConfiguration()

        let rtcIceServer = RTCIceServer(urlStrings: kIceServers)
        rtcConfig.iceServers = [rtcIceServer]
        rtcConfig.sdpSemantics = .unifiedPlan
        rtcConfig.continualGatheringPolicy = .gatherContinually

        let rtcConstraints = RTCMediaConstraints(mandatoryConstraints: nil,
                                              optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue])

        let peerConnection = self.factory.peerConnection(with: rtcConfig, constraints: rtcConstraints, delegate: delegate)

        // Audio
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = Self.factory.audioSource(with: audioConstrains)
        let audioTrack = Self.factory.audioTrack(with: audioSource, trackId: "audio0")
        peerConnection.add(audioTrack, streamIds: ["stream"])

        // Audio session
        RTCAudioSession.sharedInstance().lockForConfiguration()
        try RTCAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord.rawValue)
        try RTCAudioSession.sharedInstance().setMode(AVAudioSession.Mode.voiceChat.rawValue)
        RTCAudioSession.sharedInstance().unlockForConfiguration()

        return peerConnection
    }

    func sendSignalingMessage(offer sdp: RTCSessionDescription, completion: @escaping (_ error: Error?) -> Void) {
        guard let account = self.account else {
            self.connectionStatus = .failed(CallManagerContractError.noAccount)
            return
        }

        guard let channel = self.channel else {
            self.connectionStatus = .failed(CallManagerContractError.noChannel)
            return
        }

        let callOffer = NetworkMessage.CallOffer(from: sdp, caller: account.identity)

        self.messageSender.send(callOffer: callOffer, date: Date(), channel: channel) { (error) in
            guard let error = error else {
                completion(nil)
                return
            }

            Log.error(error, message: "Failed to send 'call offer' signaling message")
            completion(CallManagerError.signalingFailed)
        }
    }

    func sendSignalingMessage(callAcceptedAnswer sdp: RTCSessionDescription, completion: @escaping (_ error: Error?) -> Void) {
        guard let channel = self.channel else {
            self.connectionStatus = .failed(CallManagerContractError.noChannel)
            return
        }

        let callAcceptedAnswer = NetworkMessage.CallAcceptedAnswer(from: sdp)

        self.messageSender.send(callAcceptedAnswer: callAcceptedAnswer, date: Date(), channel: channel) { (error) in
            guard let error = error else {
                completion(nil)
                return
            }

            Log.error(error, message: "Failed to send 'call accepted answer' signaling message")
            completion(CallManagerError.signalingFailed)
        }
    }

    func sendSignalingMessageCallRejectedAnswer(completion: @escaping (_ error: Error?) -> Void) {
        guard let channel = self.channel else {
            self.connectionStatus = .failed(CallManagerContractError.noChannel)
            return
        }

        let callRejectedAnswer = NetworkMessage.CallRejectedAnswer()

        self.messageSender.send(callRejectedAnswer: callRejectedAnswer, date: Date(), channel: channel) { (error) in
            guard let error = error else {
                completion(nil)
                return
            }

            Log.error(error, message: "Failed to send 'call rejected answer' signaling message")
            completion(CallManagerError.signalingFailed)
        }
    }

    func sendSignalingMessage(candidate rtcIceCandidate: RTCIceCandidate, completion: @escaping (_ error: Error?) -> Void) {
        guard let channel = self.channel else {
            self.connectionStatus = .failed(CallManagerContractError.noChannel)
            return
        }

        let iceCandiadte = NetworkMessage.IceCandidate(from: rtcIceCandidate)

        self.messageSender.send(iceCandidate: iceCandiadte, date: Date(), channel: channel) { (error) in
            guard let error = error else {
                completion(nil)
                return
            }

            Log.error(error, message: "Failed to send 'ice candidate' signaling message")
            completion(CallManagerError.signalingFailed)
        }
    }
}
