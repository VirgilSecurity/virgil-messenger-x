//
//  CallMnager+CallKit.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 06.04.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import CallKit
import WebRTC

fileprivate let kFailedCallUUID = UUID(uuid: uuid_t(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))

// MARK: - Configuration
extension CallManager {
    static var providerConfiguration: CXProviderConfiguration = {
      let config = CXProviderConfiguration(localizedName: "Virgil")
      config.supportsVideo = false
      config.supportedHandleTypes = [.generic]
      config.maximumCallsPerCallGroup = 1
      config.maximumCallGroups = 1
      config.includesCallsInRecents = false

      return config
    }()

    static func createCallKitProvider() -> CXProvider {
        let provider = CXProvider(configuration: Self.providerConfiguration)

        return provider
    }
}

// MARK: - UI
extension CallManager {
    public func requestSystemStartOutgoingCall(to callee: String, completion: @escaping (Error?) -> Void) {
        let callUUID = UUID()

        Log.debug("Request start outgoing call with id \(callUUID.uuidString)")

        let handle = CXHandle(type: .generic, value: callee)
        let startCallAction = CXStartCallAction(call: callUUID, handle: handle)

        startCallAction.isVideo = false
        let transaction = CXTransaction(action: startCallAction)

        self.requestTransaction(transaction, completion: completion)
    }

    public func requestSystemStartIncomingCall(from caller: String, withId callUUID: UUID, completion: @escaping (Error?) -> Void) {
        Log.debug("Request start incoming call with id \(callUUID.uuidString)")

        let handle = CXHandle(type: .generic, value: caller)
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = handle

        self.callProvider.reportNewIncomingCall(with: callUUID, update: callUpdate) { error in
            completion(error)
        }
    }

    public func requestSystemEndCall(uuid callUUID: UUID, completion: @escaping (Error?) -> Void) {
        Log.debug("Request end call with id \(callUUID.uuidString)")

        let endCallAction = CXEndCallAction(call: callUUID)
        let transaction = CXTransaction(action: endCallAction)

        self.requestTransaction(transaction, completion: completion)
    }

    public func requestSystemEndCall(_ call: Call, completion: @escaping (Error?) -> Void) {
        self.requestSystemEndCall(uuid: call.uuid, completion: completion)
    }

    public func requestSystemDummyIncomingCall(pushKitCompletion: @escaping () -> Void) {
        self.requestSystemStartIncomingCall(from: "Failed Call...", withId: kFailedCallUUID) { error in

            if error == nil {
                pushKitCompletion()
                return
            }

            self.requestSystemEndCall(uuid: kFailedCallUUID) { _ in
                pushKitCompletion()
            }
        }
    }

    private func requestTransaction(_ transaction: CXTransaction, completion: @escaping (Error?) -> Void) {
        self.callController.request(transaction, completion: completion)
    }
}

// MARK: - Delegates
extension CallManager: CXProviderDelegate {
    public func providerDidReset(_ provider: CXProvider) {
        self.endAllCalls()
    }

    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        let callUUID = action.callUUID
        let callee = action.handle.value

        Log.debug("Proceed start of outgoing call with id \(callUUID.uuidString)")

        guard let account = self.account else {
            self.didFail(CallManagerContractError.noAccount)
            action.fail()
            return
        }

        let call = OutgoingCall(withId: callUUID, from: account.identity, to: callee, signalingTo: self)

        call.start { error in
            guard let error = error else {
                self.addCall(call)
                action.fulfill()
                return
            }

            self.didFail(error)
            action.fail()
        }

    }

    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        if #available(iOS 10, *) {
            // Workaround for webrtc on ios 10, because first incoming call does not have audio
            // due to incorrect category: AVAudioSessionCategorySoloAmbient
            // webrtc need AVAudioSessionCategoryPlayAndRecord
            try? AVAudioSession.sharedInstance().setCategory(.playAndRecord)
        }

        let callUUID = action.callUUID

        Log.debug("Answering for incomming call with id \(callUUID.uuidString)")

        guard
            let call = self.findCall(with: callUUID),
            let incommingCall = call as? IncomingCall
        else {
            Log.error(CallManagerError.noActiveCall, message: "Can not answer to the call with id \(callUUID.uuidString)")
            action.fail()
            return
        }

        incommingCall.answer()
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        let callUUID = action.callUUID

        guard callUUID != kFailedCallUUID else {
            Log.debug("Ending failed call that was not initiated due to errors.")
            action.fulfill()
            return
        }

        Log.debug("Ending call with id \(callUUID.uuidString)")

        guard let call = self.findCall(with: callUUID) else {
            Log.error(CallManagerError.noActiveCall, message: "Can not end call with id \(callUUID.uuidString)")
            action.fulfill()
            return
        }

        self.restoreAudioSessionConfig()
        self.updateRemoteCall(call, withAction: .end)

        call.end()

        self.removeCall(call)

        action.fulfill(withDateEnded: Date())
    }

    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        self.activateAudioSession(audioSession);
    }

    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        self.deactivateAudioSession(audioSession);
    }
}
