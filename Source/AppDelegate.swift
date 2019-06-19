//
//  AppDelegate.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UserNotifications
import UIKit
import Fabric
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Defining start controller
        let startController = UIStoryboard(name: StartViewController.name,
                                           bundle: Bundle.main).instantiateInitialViewController()!

        self.window?.rootViewController = startController

        // Clear core data if it's first launch
        // FIXME: if it's first launch on new major version.
        self.clearLocalStorage()

        // Registering for remote notifications
        self.registerRemoteNotifications(for: application)

        Fabric.with([Crashlytics.self])

        return true
    }

    private func clearLocalStorage() {
        if UserDefaults.standard.string(forKey: "first_launch")?.isEmpty ?? true {
            try? CoreDataHelper.shared.clearStorage()

            UserDefaults.standard.set("happened", forKey: "first_launch")
            UserDefaults.standard.synchronize()
        }
    }

    private func registerRemoteNotifications(for app: UIApplication) {
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in

            if settings.authorizationStatus == .notDetermined {

                center.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
                    Log.debug("User allowed notifications: \(granted)")

                    if granted {
                        DispatchQueue.main.async {
                            app.registerForRemoteNotifications()
                        }
                    }
                }

            } else if settings.authorizationStatus == .authorized {
                DispatchQueue.main.async {
                    app.registerForRemoteNotifications()
                }
            }
        }
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Log.debug("Received notification")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        do {
            try CoreDataHelper.shared.saveContext()
        } catch {
            Log.error("Saving Core Data context failed with error: \(error.localizedDescription)")
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Log.debug("Received device token")

        TwilioHelper.updatedPushToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.error("Failed to get token, error: \(error)")

        TwilioHelper.updatedPushToken = nil
    }
}
