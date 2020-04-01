//
//  UIViewController+Navigation.swift
//  VirgilMessenger
//
//  Created by Matheus Cardoso on 3/27/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import UIKit

extension UIViewController {
    enum NavigationStackName: String {
        case authentication = "Authentication"
        case tabBar = "TabBar"
    }

    @discardableResult
    func switchNavigationStack(to name: NavigationStackName) -> UIViewController {
        let storyboard = UIStoryboard(name: name.rawValue, bundle: Bundle.main)
        let controller = storyboard.instantiateInitialViewController() as! UINavigationController

        let window = UIApplication.shared.keyWindow!
        window.rootViewController = controller

        UIView.transition(with: window,
                          duration: UIConstants.TransitionAnimationDuration,
                          options: .transitionCrossDissolve,
                          animations: nil)

        return controller
    }
}
