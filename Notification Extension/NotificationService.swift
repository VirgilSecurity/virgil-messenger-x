//
//  NotificationService.swift
//  Notification Extension
//
//  Created by Yevhen Pyvovarov on 13.02.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import UserNotifications
import VirgilSDK
import VirgilE3Kit
import VirgilCrypto

enum NotificationServiceError: Int, LocalizedError {
    case missingIdentityInDefaults = 1
    case parsingNotificationFailed = 2
}

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    let crypto = try! VirgilCrypto()

    enum NotificationKeys: String {
        case aps = "aps"
        case alert = "alert"
        case body = "body"
        case title = "title"
    }

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {

        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        // Make sure we got mutable content
        guard let bestAttemptContent = bestAttemptContent else {
            return
        }

        do {
            guard let identity = IdentityDefaults.shared.get() else {
                throw NotificationServiceError.missingIdentityInDefaults
            }

            // Parsing userInfo of content for retreiving body and identity of recipient
            guard let aps = bestAttemptContent.userInfo[NotificationKeys.aps.rawValue] as? [String: Any],
                let alert = aps[NotificationKeys.alert.rawValue] as? [String: String],
                let body = alert[NotificationKeys.body.rawValue],
                let title = alert[NotificationKeys.title.rawValue] else {
                    throw NotificationServiceError.parsingNotificationFailed
            }
            
            let encryptedMessage = try EncryptedMessage.import(body)

            // Initializing KeyStorage with root application name. We need it to fetch shared key from root app
            let storageParams = try KeychainStorageParams.makeKeychainStorageParams(appName: Constants.appId)

            let client = Client(crypto: self.crypto)

            let tokenCallback = client.makeTokenCallback(identity: identity)

            let params = EThreeParams(identity: identity, tokenCallback: tokenCallback)
            params.storageParams = storageParams
            let ethree = try EThree(params: params)
            
            let card = try ethree.findUser(with: title).startSync().get()

            // Decrypting notification body
            let decrypted = try ethree.authDecrypt(data: encryptedMessage.ciphertext, from: card)

            // Changing body of notification from ciphertext to decrypted message
            // FIXME
            bestAttemptContent.body = "decrypted"

            contentHandler(bestAttemptContent)

            // Note: We got body from userInfo, not from bestAttemptContent.body directly in a reason of 1000 symbol restriction
        }
        catch {
            bestAttemptContent.body = "New Message"

            contentHandler(bestAttemptContent)
            
            print("Notification was not decrypted with error: \(error.localizedDescription)")
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

}
