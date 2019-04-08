//
//  AppDelegate.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit
import CoreData
import VirgilSDK
import Fabric
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        UIApplication.shared.delegate?.window??.rootViewController = UIStoryboard(name: StartViewController.name, bundle: Bundle.main).instantiateInitialViewController()!

        if UserDefaults.standard.string(forKey: "first_launch")?.isEmpty ?? true {
            let context = persistentContainer.viewContext
            let fetchRequest =
                NSFetchRequest<NSManagedObject>(entityName: CoreDataHelper.Entities.account.rawValue)
            if let result = try? context.fetch(fetchRequest) {
                for object in result {
                    context.delete(object)
                }
            }

            UserDefaults.standard.set("happened", forKey: "first_launch")
            UserDefaults.standard.synchronize()
        }

        Fabric.with([Crashlytics.self])

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        self.saveContext()
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "VirgilMessenger-1")
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

    func saveContext () {
        Log.debug("saving context")
        let context = persistentContainer.viewContext
        if context.hasChanges {
            Log.debug("context has changes")
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                Log.error("save context failed: \(nserror.localizedDescription)")
            }
        }
    }
}
