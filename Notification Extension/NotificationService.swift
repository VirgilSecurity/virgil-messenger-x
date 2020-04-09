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
    case dataToStrFailed = 3
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

    struct NotificationInfo {
        let sender: String
        let encryptedMessage: EncryptedMessage
    }

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {

        self.contentHandler = contentHandler

        guard let bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent else {
            // FIXME: add Logs
            return
        }

        bestAttemptContent.body = "New Message"

        self.bestAttemptContent = bestAttemptContent

        self.updateBadge(for: bestAttemptContent)

        do {
            let notificationInfo = try self.parse(content: bestAttemptContent)

            let decrypted = try self.decrypt(notificationInfo: notificationInfo)

            let message = try self.process(decrypted: decrypted,
                                           version: notificationInfo.encryptedMessage.modelVersion)

            bestAttemptContent.body = message

            contentHandler(bestAttemptContent)

            // Note: We got body from userInfo, not from bestAttemptContent.body directly in a reason of 1000 symbol restriction
        }
        catch {
            // FIXME: add Logs
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

    private func updateBadge(for content: UNMutableNotificationContent) {
        let oldBadgeCount: Int = SharedDefaults.shared.get(.unreadCount) ?? 0
        let newBadgeCount = oldBadgeCount + 1

        SharedDefaults.shared.set(unreadCount: newBadgeCount)
        content.badge = NSNumber(value: newBadgeCount)
    }

    private func parse(content: UNMutableNotificationContent) throws -> NotificationInfo {
        guard let aps = content.userInfo[NotificationKeys.aps.rawValue] as? [String: Any],
            let alert = aps[NotificationKeys.alert.rawValue] as? [String: String],
            let body = alert[NotificationKeys.body.rawValue],
            let title = alert[NotificationKeys.title.rawValue] else {
                throw NotificationServiceError.parsingNotificationFailed
        }

        let encryptedMessage = try EncryptedMessage.import(body)

        return NotificationInfo(sender: title, encryptedMessage: encryptedMessage)
    }

    private func decrypt(notificationInfo: NotificationInfo) throws -> Data {
        guard let identity: String = SharedDefaults.shared.get(.identity) else {
            throw NotificationServiceError.missingIdentityInDefaults
        }

        // Initializing KeyStorage with root application name. We need it to fetch shared key from root app
        let storageParams = try KeychainStorageParams.makeKeychainStorageParams(appName: Constants.KeychainGroup)

        let client = Client(crypto: self.crypto)

        let tokenCallback = client.makeTokenCallback(identity: identity)

        let params = EThreeParams(identity: identity, tokenCallback: tokenCallback)
        params.storageParams = storageParams
        let ethree = try EThree(params: params)

        let card = try ethree.findUser(with: notificationInfo.sender)
            .startSync()
            .get()

        return try ethree.authDecrypt(data: notificationInfo.encryptedMessage.ciphertext, from: card)
    }

    private func process(decrypted: Data, version: EncryptedMessageVersion) throws -> String {
        let message: String

        switch version {
        case .v1:
            guard let string = String(data: decrypted, encoding: .utf8) else {
                throw NotificationServiceError.dataToStrFailed
            }

            message = string
        case .v2:
            let content = try MessageContent.import(from: decrypted)

            message = content.notificationBody
        }

        return message
    }
}
