//
//  Date.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 12/7/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit

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

    func shortString() -> String {
        let dateFormatter = DateFormatter()

        if self.minutes(from: Date()) < 2 {
            return "now"
        }
        else if self.days(from: Date()) < 1 {
            dateFormatter.dateStyle = DateFormatter.Style.none
            dateFormatter.timeStyle = DateFormatter.Style.short
        }
        else {
            dateFormatter.dateStyle = DateFormatter.Style.short
            dateFormatter.timeStyle = DateFormatter.Style.none
        }

        let shortString = dateFormatter.string(from: self)

        return shortString
    }
}
