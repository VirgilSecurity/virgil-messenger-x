//
//  Notifications.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 6/27/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import Foundation

public class Notifications {
    private static let center: NotificationCenter = NotificationCenter.default

    public enum EmptyNotification: String {
        case initializingSucceed = "Notifications.InitializingSucceed"
        case updatingSucceed = "Notifications.UpdatingSucceed"

        case channelAdded = "Notifications.ChannelAdded"
        case channelDeleted = "Notifications.ChannelDeleted"
        
        case messageAdded = "Notifications.MessageAdded"
    }

    public enum Notifications: String {
        case connectionStateUpdated = "Notifications.ConnectionStateUpdated"
        case errored = "Notifications.Errored"
        case messageAddedToCurrentChannel = "Notifications.MessageAddedToCurrentChannel"
    }

    private enum NotificationKeys: String {
        case newState = "NotificationKeys.NewState"
        case message = "NotificationKeys.Message"
        case error = "NotificationKeys.Error"
    }

    private static func notification(_ notification: Notifications) -> Notification.Name {
        return Notification.Name(rawValue: notification.rawValue)
    }

    private static func notification(_ notification: EmptyNotification) -> Notification.Name {
        return Notification.Name(rawValue: notification.rawValue)
    }

    public static func removeObservers(_ object: Any) {
        self.center.removeObserver(object)
    }
}

extension Notifications {
    public static func post(error: Error) {
        let notification = self.notification(.errored)
        let userInfo = [NotificationKeys.error.rawValue: error]

        self.center.post(name: notification, object: self, userInfo: userInfo)
    }

    public static func post(connectionState: Twilio.ConnectionState) {
        let notification = self.notification(.connectionStateUpdated)
        let userInfo = [NotificationKeys.newState.rawValue: connectionState]

        self.center.post(name: notification, object: self, userInfo: userInfo)
    }

    public static func post(message: Message) {
        let notification = self.notification(.messageAddedToCurrentChannel)
        let userInfo = [NotificationKeys.message.rawValue: message]

        self.center.post(name: notification, object: self, userInfo: userInfo)
    }

    public static func post(_ notification: EmptyNotification) {
        let notification = self.notification(notification)

        self.center.post(name: notification, object: self)
    }
}

extension Notifications {
    public static func observe(_ object: Any, for notification: EmptyNotification, task: @escaping () -> Void)  {
        let notification = self.notification(notification)

        self.center.addObserver(forName: notification, object: nil, queue: nil) { _ in
            task()
        }
    }

    public static func observe(_ object: Any, for notification: Notifications, task: @escaping () -> Void)  {
        let notification = self.notification(notification)

        self.center.addObserver(forName: notification, object: nil, queue: nil) { _ in
            task()
        }
    }

    public static func observe(_ object: Any, for notifications: [EmptyNotification], task: @escaping () -> Void)  {
        notifications.forEach {
            let notification = self.notification($0)

            self.center.addObserver(forName: notification, object: nil, queue: nil) { _ in
                task()
            }
        }
    }

    public static func observe(_ object: Any, task: @escaping (Message) -> Void) {
        let notification = self.notification(.messageAddedToCurrentChannel)

        self.center.addObserver(forName: notification, object: nil, queue: nil) { notification in
            guard let userInfo = notification.userInfo,
                let message = userInfo[NotificationKeys.message.rawValue] as? Message else {
                    Log.error("invalid notification")
                    return
            }

            task(message)
        }
    }

    public static func observe(_ object: Any, task: @escaping (Error) -> Void) {
        let notification = self.notification(.errored)

        self.center.addObserver(forName: notification, object: nil, queue: nil) { notification in
            guard let userInfo = notification.userInfo,
                let error = userInfo[NotificationKeys.error.rawValue] as? Error else {
                    Log.error("invalid notification")
                    return
            }

            task(error)
        }
    }
}
