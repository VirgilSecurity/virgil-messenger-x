//
//  ColorPair.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/13/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit

public class ColorPair {
    var first: CGColor
    var second: CGColor

    init(_ first: UIColor, _ second: UIColor) {
        self.first = first.cgColor
        self.second = second.cgColor
    }
}
