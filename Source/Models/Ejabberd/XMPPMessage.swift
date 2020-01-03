//
//  XMPPMessage.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 03.01.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import XMPPFrameworkSwift

extension XMPPMessage {
    func getBody() throws -> String {
        guard let body = self.body else {
            throw NSError()
        }

        return body
    }

    func getAuthor() throws -> String {
        guard let author = self.from?.user else {
            throw NSError()
        }

        return author
    }
}
