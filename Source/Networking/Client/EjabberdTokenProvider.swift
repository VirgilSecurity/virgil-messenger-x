//
//  EjabberdTokenProvider.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/30/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import VirgilSDK

class EjabberdTokenProvider {
    public typealias TokenCallback = (EjabberdToken?, Error?) -> Void

    private(set) var token: EjabberdToken?

    public let renewTokenCallback: (@escaping TokenCallback) -> Void

    private let semaphore = DispatchSemaphore(value: 1)

    public init(identity: String, client: Client) {
        self.renewTokenCallback = { completion in
            do {
                let string = try client.getEjabberdToken(identity: identity)

                completion(try EjabberdToken(string), nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }

    public func getToken() -> CallbackOperation<EjabberdToken> {
        CallbackOperation { _, completion in
            if let token = self.token, !token.isExpired() {
                completion(token, nil)
                return
            }

            self.semaphore.wait()

            if let token = self.token, !token.isExpired() {
                self.semaphore.signal()
                completion(token, nil)
                return
            }

            self.renewTokenCallback { token, error in
                guard let token = token, error == nil else {
                    self.semaphore.signal()
                    completion(nil, error)
                    return
                }

                self.token = token
                self.semaphore.signal()

                completion(token, nil)
            }
        }
    }
}
