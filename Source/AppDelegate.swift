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
import VirgilSDK
import CocoaLumberjack

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Defining start controller
        let startStoryboard = UIStoryboard(name: StartViewController.name, bundle: Bundle.main)
        let startController = startStoryboard.instantiateInitialViewController()!

        let logger = DDTTYLogger.sharedInstance!
        DDLog.add(logger, with: .all)

        self.window?.rootViewController = startController

        // Clear core data if it's first launch
        self.cleanLocalStorage()

        // Registering for remote notifications
        self.registerRemoteNotifications(for: application)

        // Clean notifications
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        Fabric.with([Crashlytics.self])

        return true
    }

    private func cleanLocalStorage() {
        do {
            let key = CoreData.dbName

            if UserDefaults.standard.string(forKey: key)?.isEmpty ?? true {
                try? CoreData.shared.clearStorage()

                // Clean keychain
                let params = try KeychainStorageParams.makeKeychainStorageParams()
                let keychain = KeychainStorage(storageParams: params)

                try keychain.deleteAllEntries()

                UserDefaults.standard.set("initialized", forKey: key)
                UserDefaults.standard.synchronize()
            }
        }
        catch {
            Log.error("cleanLocalStorageError: \(error.localizedDescription)")
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

            }
            else if settings.authorizationStatus == .authorized {
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
            try CoreData.shared.saveContext()
        } catch {
            Log.error("Saving Core Data context failed with error: \(error.localizedDescription)")
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Log.debug("Received device token: \(deviceToken.hexEncodedString())")

        Ejabberd.updatedPushToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.error("Failed to get token, error: \(error)")

        Ejabberd.updatedPushToken = nil
    }
}
