//
//  SwipableNavigationController.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/26/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import UIKit

class SwipeableNavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupFullWidthBackGesture()
    }

    private lazy var fullWidthBackGestureRecognizer = UIPanGestureRecognizer()

    private func setupFullWidthBackGesture() {
        // The trick here is to wire up our full-width `fullWidthBackGestureRecognizer` to execute the same handler as
        // the system `interactivePopGestureRecognizer`. That's done by assigning the same "targets" (effectively
        // object and selector) of the system one to our gesture recognizer.

        guard
            let interactivePopGestureRecognizer = interactivePopGestureRecognizer,
            let targets = interactivePopGestureRecognizer.value(forKey: "targets")
        else {
            // TODO: Add logs
            return
        }

        self.fullWidthBackGestureRecognizer.setValue(targets, forKey: "targets")
        self.fullWidthBackGestureRecognizer.delegate = self
        self.view.addGestureRecognizer(fullWidthBackGestureRecognizer)
    }
}

extension SwipeableNavigationController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let isSystemSwipeToBackEnabled = interactivePopGestureRecognizer?.isEnabled == true
        let isThereStackedViewControllers = viewControllers.count > 1

        return isSystemSwipeToBackEnabled && isThereStackedViewControllers
    }
}
