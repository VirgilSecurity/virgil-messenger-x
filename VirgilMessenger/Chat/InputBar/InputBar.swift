//
//  InputBar.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 12/7/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import ChattoAdditions

class InputBar : ChatInputBar {
    override class open func loadNib() -> ChatInputBar {
        let nibName = "InputBar"
        let view = Bundle.main.loadNibNamed(nibName, owner: nil, options: nil)!.first as! ChatInputBar
        view.translatesAutoresizingMaskIntoConstraints = false
        view.frame = CGRect.zero
        return view
    }
}

class DemoExpandableTextView: ExpandableTextView {}
class DemoHorizontalStackScrollView: HorizontalStackScrollView {}
