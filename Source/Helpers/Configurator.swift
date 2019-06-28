//
//  Configurator.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/26/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK

public class Configurator {
    private(set) static var isInitialized: Bool = false {
        didSet {
            if isInitialized == true {
                Notifications.post(.initializingSucceed)
            }
        }
    }
    private(set) static var isUpdated: Bool = false {
        didSet {
            if isUpdated == true {
                Notifications.post(.updatingSucceed)
            }
        }
    }

    private static func initialize() -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let account = try CoreData.shared.getCurrentAccount()
                let identity = account.identity

                let initPFS = Virgil.shared.makeInitPFSOperation(identity: identity)
                let initTwilio = Twilio.makeInitTwilioOperation(identity: identity,
                                                                client: Virgil.shared.client)
                let completion = OperationUtils.makeCompletionOperation { (_ result: Void?, error: Error?) in
                    if error == nil {
                        self.isInitialized = true
                    }

                    completion(result, error)
                }

                completion.addDependency(initPFS)
                completion.addDependency(initTwilio)

                let queue = OperationQueue()
                queue.addOperations([initPFS, initTwilio, completion], waitUntilFinished: false)
            } catch {
                completion(nil, error)
            }
        }
    }

    public static func configure() {
        let initialize = self.initialize()
        let update = ChatsManager.updateChannels()

        update.addDependency(initialize)

        let completion = OperationUtils.makeCompletionOperation { (_ result: Void?, error: Error?) in
            if let error = error {
                Notifications.post(error: error)
            } else {
                self.isUpdated = true
            }
        }

        completion.addDependency(update)

        let queue = OperationQueue()
        queue.addOperations([initialize, update, completion], waitUntilFinished: false)
    }
}
