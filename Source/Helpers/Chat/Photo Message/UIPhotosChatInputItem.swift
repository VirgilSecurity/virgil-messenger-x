//
//  UIPhotosChatInputItem.swift
//  Morse
//
//  Created by Eugen Pivovarov on 5/25/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import ChattoAdditions

class UIPhotosChatInputItem: PhotosChatInputItem {
    override var inputView: UIView? {
        if let subviews = super.inputView?.subviews {
            for subview in subviews {
                subview.backgroundColor = UIColor(rgb: 0x20232B)
            }
        }
        return super.inputView
    }
}
