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
    
    func resized(withPercentage percentage: CGFloat, isOpaque: Bool = true) -> UIImage? {
        let width = self.size.width * percentage
        let height = self.size.height * percentage
        let canvas = CGSize(width: width, height: height)
        
        let format = imageRendererFormat
        format.opaque = isOpaque
        
        return UIGraphicsImageRenderer(size: canvas, format: format).image {
            _ in draw(in: CGRect(origin: .zero, size: canvas))
        }
    }
    
    func resized(to maxDimention: CGFloat, isOpaque: Bool = true) -> UIImage? {
        let width: CGFloat
        let height: CGFloat
        
        if self.size.height < self.size.width {
            width = maxDimention
            height = CGFloat(ceil((width * self.size.height) / self.size.width))
        }
        else {
            height = maxDimention
            width = CGFloat(ceil((height * self.size.width) / self.size.height))
        }
        
        let canvas = CGSize(width: width, height: height)
        
        let format = imageRendererFormat
        format.opaque = isOpaque
        
        return UIGraphicsImageRenderer(size: canvas, format: format).image {
            _ in draw(in: CGRect(origin: .zero, size: canvas))
        }
    }
}
