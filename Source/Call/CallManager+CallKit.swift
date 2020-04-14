//
//  CallMnager+CallKit.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 06.04.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation
import CallKit

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

    public func requestSystemEndCall(_ call: Call, completion: @escaping (Error?) -> Void) {
        Log.debug("Request end call with id \(call.uuid.uuidString)")

        let endCallAction = CXEndCallAction(call: call.uuid)
        let transaction = CXTransaction(action: endCallAction)

        self.requestTransaction(transaction, completion: completion)
    }

    private func requestTransaction(_ transaction: CXTransaction, completion: @escaping (Error?) -> Void) {
        self.callController.request(transaction) { error in
            completion(error)
        }
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

        let call = OutgoingCall(withId: callUUID, to: callee, from: account.identity, signalingTo: self)

        self.addCall(call)
        call.start()

        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
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

        Log.debug("Ending call with id \(callUUID.uuidString)")

        guard
            let call = self.findCall(with: callUUID)
        else {
            Log.error(CallManagerError.noActiveCall, message: "Can not end call with id \(callUUID.uuidString)")
            action.fail()
            return
        }

        call.end()
        self.removeCall(call)
        action.fulfill()
    }
}
