//
//  CompletionQueueItem.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 5/14/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import VirgilSDK

struct CompletionQueueItem {
    enum ActionType {
        case blockUnblock
    }

    let type: ActionType
    let completion: (Error?) -> Void

    let mutex: Mutex = Mutex()

    init(type: ActionType, completion: @escaping (Error?) -> Void) throws {
        self.type = type
        self.completion = completion

        try self.mutex.lock()
    }
}
