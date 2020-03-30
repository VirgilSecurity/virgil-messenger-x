//
//  LocalPushNotifications.swift
//  VirgilMessenger
//
//  Created by Matheus Cardoso on 3/26/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import UserNotifications

public class PushNotifications {
    private static let center: UNUserNotificationCenter = .current()
}

extension PushNotifications {
    static func post(messageContent: MessageContent, author: String) {
        // create the content for the notification
        let content = UNMutableNotificationContent()
        content.title = author
        content.body = messageContent.notificationBody
        content.sound = .default

        // notification trigger can be based on time, calendar or location
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1,
                                                        repeats: false)

        // create request to display
        let request = UNNotificationRequest(identifier: "ContentIdentifier",
                                            content: content,
                                            trigger: trigger)

        // add request to notification center
        center.add(request) { error in
            if let error = error {
                Log.error(error, message: "Post local notification failed")
            }
        }
    }

    static func cleanNotifications() {
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
    }
}
