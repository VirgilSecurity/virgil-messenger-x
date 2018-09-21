//
//  UIImage+Resize.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 9/11/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import UIKit

extension UIImage {
    func resize(to size: CGSize) -> UIImage {
        let hasAlpha = true
        let scale: CGFloat = 0.0 // Use scale factor of main screen

        UIGraphicsBeginImageContextWithOptions(size, !hasAlpha, scale)
        self.draw(in: CGRect(origin: CGPoint.zero, size: size))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()

        return scaledImage!
    }
}
