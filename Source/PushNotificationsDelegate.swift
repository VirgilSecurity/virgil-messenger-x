//
//  PushNotificationsDelegate.swift
//  VirgilMessenger
//
//  Created by Matheus Cardoso on 3/26/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import UserNotifications
import UIKit

class PushNotificationsDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        PushNotifications.cleanNotifications()

        let navigationController = UIApplication.shared
            .keyWindow?
            .rootViewController as? UINavigationController

        navigationController?.popViewController(animated: false)

        let tabBar = navigationController?.viewControllers.first as? UITabBarController
        let swipeableController = tabBar?.viewControllers?.first as? SwipeableNavigationController
        let chatList = swipeableController?.viewControllers.first as? ChatListViewController

        let title = response.notification.request.content.title
        if let channel = chatList?.channels.first(where: { $0.name == title }) {
            chatList?.moveToChannel(channel)
        }

        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert])
    }
}
