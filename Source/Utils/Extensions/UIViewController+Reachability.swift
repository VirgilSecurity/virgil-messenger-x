//
//  UIViewController+Reachibility.swift
//  Morse
//
//  Created by Eugen Pivovarov on 1/3/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit
import SystemConfiguration

extension UIViewController {
    enum ReachabilityStatus {
        case notReachable
        case reachableViaWWAN
        case reachableViaWiFi
    }

    internal var reachabilityStatus: ReachabilityStatus {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)

        let defaultRouteReachabilityOptional = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }

        var flags: SCNetworkReachabilityFlags = []

        guard let defaultRouteReachability = defaultRouteReachabilityOptional,
            SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) else {
                return .notReachable
        }

        if flags.contains(.reachable) == false {
            // The target host is not reachable.
            return .notReachable
        } else if flags.contains(.isWWAN) == true {
            // WWAN connections are OK if the calling application is using the CFNetwork APIs.
            return .reachableViaWWAN
        } else if flags.contains(.connectionRequired) == false {
            // If the target host is reachable and no connection is required then we'll assume that you're on Wi-Fi...
            return .reachableViaWiFi
        } else if (flags.contains(.connectionOnDemand) == true || flags.contains(.connectionOnTraffic) == true) && flags.contains(.interventionRequired) == false {
            // The connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs and no [user] intervention is needed
            return .reachableViaWiFi
        } else {
            return .notReachable
        }
    }

    internal func checkReachability() -> Bool {
        guard self.reachabilityStatus != .notReachable else {
            self.alert(UserFriendlyError.noConnection)
            return false
        }

        return true
    }
}
