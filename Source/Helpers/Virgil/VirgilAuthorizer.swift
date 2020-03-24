//
//  VirgilAuthorizer.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/25/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilCrypto
import VirgilE3Kit

public class VirgilAuthorizer {
    public let client: Client

    public init() throws {
        let crypto = try VirgilCrypto()
        self.client = Client(crypto: crypto)
    }

    public func signIn(identity: String) throws {
        try Virgil.initialize(identity: identity, client: self.client)

        guard try Virgil.ethree.localKeyStorage.exists() else {
            throw UserFriendlyError.noUserOnDevice
        }
    }

    public func signUp(identity: String) throws {
        do {
            try Virgil.initialize(identity: identity, client: self.client)

            let publishCardCallback = self.client.makePublishCardCallback(verifier: Virgil.shared.verifier)

            try Virgil.ethree.register(publishCardCallback: publishCardCallback)
                .startSync()
                .get()
            
            Log.debug("Yo")
        }
        catch EThreeError.privateKeyExists {
            throw UserFriendlyError.usernameAlreadyUsed
        }
        catch {
            throw error
        }
    }

    public func logOut() {
        try? Virgil.ethree.cleanUp()
    }
}
