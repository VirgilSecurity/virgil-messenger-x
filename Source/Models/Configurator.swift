//
//  Configurator.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/26/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK

public class Configurator {
    private let queue = DispatchQueue(label: "ConfiguratorQueue")

    public func configure() -> GenericOperation<Void> {
        return CallbackOperation { _, completion in
            self.queue.async {
                do {
                    guard let identity = CoreDataHelper.shared.currentAccount?.identity else {
                        throw NSError()
                    }

                    try VirgilHelper.initialize(identity: identity)

                    let initPFSOperation = VirgilHelper.shared.makeInitPFSOperation(identity: identity)
                    let initTwilioOperation = TwilioHelper.makeInitTwilioOperation(identity: identity,
                                                                                   client: VirgilHelper.shared.client)

                    let operations = [initPFSOperation, initTwilioOperation]
                    let completionOperation = OperationUtils.makeCompletionOperation(completion: completion)

                    operations.forEach {
                        completionOperation.addDependency($0)
                    }

                    let queue = OperationQueue()
                    queue.addOperations(operations + [completionOperation], waitUntilFinished: true)
                } catch {
                    completion(nil, error)
                }
            }
        }
    }
}
