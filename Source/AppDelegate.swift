//
//  AppDelegate.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UserNotifications
import UIKit
import CoreData
import VirgilSDK
import Fabric
import Crashlytics


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var updatedPushToken: Data?
    var receivedNotification: [NSObject : AnyObject]?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Defining start controller
        let startController = UIStoryboard(name: StartViewController.name,
                                           bundle: Bundle.main).instantiateInitialViewController()!

        UIApplication.shared.delegate?.window??.rootViewController = startController

        // Clear core data if it's first launch
        // FIXME: if it's first launch on new major version.
        if UserDefaults.standard.string(forKey: "first_launch")?.isEmpty ?? true {
            let context = self.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: Account.EntityName)
            if let result = try? context.fetch(fetchRequest) {
                for object in result {
                    context.delete(object)
                }
            }

            UserDefaults.standard.set("happened", forKey: "first_launch")
            UserDefaults.standard.synchronize()
        }

        // Registering for remote notifications
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { (settings) in
            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
                    Log.debug("User allowed notifications: \(granted)")
                    if granted {
                        DispatchQueue.main.async {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    }
                }
            }
        }

        Fabric.with([Crashlytics.self])

        return true
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Log.debug("Received notification")
        // If your application supports multiple types of push notifications, you may wish to limit which ones you send to the TwilioChatClient here
//        if let chatClient = chatClient, chatClient.user != nil {
//            // If your reference to the Chat client exists and is initialized, send the notification to it
//            chatClient.handleNotification(userInfo) { (result) in
//                if (!result.isSuccessful()) {
//                    // Handling of notification was not successful, retry?
//                }
//            }
//        } else {
//            // Store the notification for later handling
//            receivedNotification = userInfo
//        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        do {
            try self.saveContext()
        } catch {
            Log.error("Saving Core Data context failed with error: \(error.localizedDescription)")
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Log.debug("Received device token")
        // FIXME
//        if let chatClient = chatClient, chatClient.user != nil {
//            chatClient.register(withNotificationToken: deviceToken) { (result) in
//                if (!result.isSuccessful()) {
//                    // try registration again or verify token
//                }
//            }
//        } else {
            self.updatedPushToken = deviceToken
//        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.error("Failed to get token, error: \(error)")
        self.updatedPushToken = nil
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "VirgilMessenger-2")
        container.loadPersistentStores(completionHandler: { storeDescription, error in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                Log.error("save context failed: \(error.localizedDescription)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext() throws {
        let context = self.persistentContainer.viewContext

        if self.persistentContainer.viewContext.hasChanges {
            try context.save()
        }
    }
}
