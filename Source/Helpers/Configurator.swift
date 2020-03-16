//
//  Configurator.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/26/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK

public class Configurator {
    public static var state: String? {
        if !Configurator.isInitialized {
            return "Connecting"
        } else if !Configurator.isUpdated {
            return "Updating"
        }

        return nil
    }

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
                let account = try Storage.shared.getCurrentAccount()
                let identity = account.identity

                try Ejabberd.shared.initialize(identity: identity)

                self.isInitialized = true

                completion((), nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }

    public static func configure() {
        self.reset()

        let initialize = self.initialize()

        let completion = OperationUtils.makeCompletionOperation { (_ result: Void?, error: Error?) in
            if let error = error {
                Notifications.post(error: error)
            }
            else {
                self.isUpdated = true
            }
        }

        completion.addDependency(initialize)

        let queue = OperationQueue()
        queue.addOperations([initialize, completion], waitUntilFinished: false)
    }

    public static func reset() {
        self.isInitialized = false
        self.isUpdated = false
    }
}
