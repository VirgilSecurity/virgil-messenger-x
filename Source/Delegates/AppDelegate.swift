//
//  AppDelegate.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UserNotifications
import UIKit
import VirgilSDK
import Firebase
import CocoaLumberjackSwift
import WebRTC
import PushKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    let pushNotificationsDelegate = PushNotificationsDelegate()
    let pushRegistryDelegate = PushRegistryDelegate()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Firebase configuration for Crashlytics
        FirebaseApp.configure()

        // WebRTC
        RTCInitializeSSL()

        // Defining start controller
        let startStoryboard = UIStoryboard(name: StartViewController.name, bundle: Bundle.main)
        let startController = startStoryboard.instantiateInitialViewController()!

        let logger = DDOSLogger.sharedInstance
        DDLog.add(logger, with: .all)

        self.window?.rootViewController = startController

        // Clear core data if it's first launch
        self.cleanLocalStorage()

        // Registering for remote notifications
        self.registerRemoteNotifications(for: application)

        // Clean notifications
        self.cleanNotifications()

        // Registering for Voip notifications
        self.registerVoip()

        return true
    }

    private func registerVoip() {
        let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        voipRegistry.delegate = self.pushRegistryDelegate
        voipRegistry.desiredPushTypes = [.voIP]
    }

    private func cleanLocalStorage() {
        do {
            let key = Storage.dbName

            if UserDefaults.standard.string(forKey: key)?.isEmpty ?? true {
                try? Storage.shared.clearStorage()

                // Clean keychain
                let params = try KeychainStorageParams.makeKeychainStorageParams(appName: Constants.KeychainGroup)
                let keychain = KeychainStorage(storageParams: params)

                try keychain.deleteAllEntries()

                UserDefaults.standard.set("initialized", forKey: key)
                UserDefaults.standard.synchronize()
            }
        }
        catch {
            Log.error(error, message: "Clean Local Storage on startup failed")
        }
    }

    private func registerRemoteNotifications(for app: UIApplication) {
        let center = UNUserNotificationCenter.current()

        center.delegate = self.pushNotificationsDelegate

        center.getNotificationSettings { settings in

            if settings.authorizationStatus == .notDetermined {

                center.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
                    Log.debug("User allowed notifications: \(granted)")

                    if granted {
                        DispatchQueue.main.async {
                            app.registerForRemoteNotifications()
                        }
                    }

                    if let error = error {
                        Log.error(error, message: "Granting notifications permissions failed")
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

    private func cleanNotifications() {
        PushNotifications.cleanNotifications()
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Log.debug("Received notification")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        do {
            RTCCleanupSSL()

            try Storage.shared.saveContext()

            UnreadManager.shared.update()
        }
        catch {
            Log.error(error, message: "Saving Core Data context on app termination failed")
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Log.debug("Received device push token: \(deviceToken.hexEncodedString())")

        if Ejabberd.shared.state == .connected {
            Ejabberd.shared.registerForNotifications(deviceToken: deviceToken)
        }

        Ejabberd.updatedPushToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.error(error, message: "Failed to get device token")

        Ejabberd.updatedPushToken = nil
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        Ejabberd.shared.set(status: .online)

        self.cleanNotifications()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        Ejabberd.shared.set(status: .unavailable)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        UnreadManager.shared.update()
    }
}
