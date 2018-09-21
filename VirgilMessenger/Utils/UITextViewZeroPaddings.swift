//
//  UITextViewZeroPaddings.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 7/26/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import UIKit

@IBDesignable class UITextViewZeroPaddings: UITextView {
    override func layoutSubviews() {
        super.layoutSubviews()
        setup()
    }
    func setup() {
        textContainerInset = UIEdgeInsets.zero
        textContainer.lineFragmentPadding = 0
    }
}
