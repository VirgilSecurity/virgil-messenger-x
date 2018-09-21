//
//  Constants.swift
//  VirgilSigner iOS
//
//  Created by Oleksandr Deundiak on 9/25/17.
//  Copyright © 2017 Virgil Security. All rights reserved.
//

import UIKit

class ChatConstants {
    static let limitLength = 32
    static let characterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,-()/='+:?!%&*<>;{}@#_")
    static let chatMaxCharectersCount: UInt = 1000
    static let chatPageSize = 20
}

class UIConstants {
    static let TransitionAnimationDuration: TimeInterval = 0.3

    static var colorPairs: [ColorPair] = [ColorPair(UIColor(rgb: 0x009DFF), UIColor(rgb: 0x6AC7FF)),
                             ColorPair(UIColor(rgb: 0x541C12), UIColor(rgb: 0x9E3621)),
                             ColorPair(UIColor(rgb: 0x156363), UIColor(rgb: 0x21999E)),
                             ColorPair(UIColor(rgb: 0x54CB68), UIColor(rgb: 0x9ADD7D)),          //light green
                             ColorPair(UIColor(rgb: 0x665FFF), UIColor(rgb: 0x81ADFF)),          //strange
                             ColorPair(UIColor(rgb: 0xFFA95C), UIColor(rgb: 0xFFCB66))           //orange-yellow
    ]
}

class ColorPair {
    var first: CGColor
    var second: CGColor

    init(_ first: UIColor, _ second: UIColor) {
        self.first = first.cgColor
        self.second = second.cgColor
    }
}
