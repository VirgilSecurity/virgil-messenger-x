//
//  Configurator.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/26/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK

public class Configurator {
    private(set) var isConfigured: Bool = false

    public func configure(completion: @escaping (Error?) -> Void) {
        do {
            let account = try CoreData.shared.getCurrentAccount()
            let identity = account.identity

            let initPFSOperation = Virgil.shared.makeInitPFSOperation(identity: identity)
            let initTwilioOperation = Twilio.makeInitTwilioOperation(identity: identity,
                                                                           client: Virgil.shared.client)
            let updateChannelsOperation = ChatsManager.makeUpdateChannelsOperation()

            let operations = [initPFSOperation, initTwilioOperation, updateChannelsOperation]
            let completionOperation = OperationUtils.makeCompletionOperation { (_: Void?, error: Error?) in
                self.isConfigured = true
                completion(error)
            }

            updateChannelsOperation.addDependency(initPFSOperation)
            updateChannelsOperation.addDependency(initTwilioOperation)

            operations.forEach {
                completionOperation.addDependency($0)
            }

            let queue = OperationQueue()
            queue.addOperations(operations + [completionOperation], waitUntilFinished: false)
        } catch {
            completion(error)
        }
    }
}
