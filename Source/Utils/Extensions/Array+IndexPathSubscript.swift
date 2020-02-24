//
//  Array+IndexPathSubscript.swift
//  VirgilMessenger
//
//  Created by Matheus Cardoso on 2/21/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import Foundation

extension Array where Element: Collection, Element.Index == Int {
    subscript(_ indexPath: IndexPath) -> Element.Iterator.Element {
        return self[indexPath.section][indexPath.row]
    }
}
