//
//  UIColorUtils.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 12/7/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    convenience init(rgb: Int) {
        self.init(
            red: (rgb >> 16) & 0xFF,
            green: (rgb >> 8) & 0xFF,
            blue: rgb & 0xFF
        )
    }
}

extension Date {
    /// Returns the amount of days from another date
    func days(from date: Date) -> Int {
        return abs(Calendar.current.dateComponents([.day], from: date, to: self).day ?? 0)
    }
    /// Returns the amount of hours from another date
    func hours(from date: Date) -> Int {
        return abs(Calendar.current.dateComponents([.hour], from: date, to: self).hour ?? 0)
    }
    /// Returns the amount of minutes from another date
    func minutes(from date: Date) -> Int {
        return abs(Calendar.current.dateComponents([.minute], from: date, to: self).minute ?? 0)
    }
    /// Returns the amount of seconds from another date
    func seconds(from date: Date) -> Int {
        return abs(Calendar.current.dateComponents([.second], from: date, to: self).second ?? 0)
    }
}
