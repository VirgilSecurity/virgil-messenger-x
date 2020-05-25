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
    case ratchetChannelNotFound = 4
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

            let decryptedData = try self.decrypt(notificationInfo: notificationInfo)

            let message = try self.process(notificationInfo: notificationInfo,
                                           decryptedData: decryptedData,
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

    private func decrypt(notificationInfo: NotificationInfo) throws -> Data? {
        guard let identity: String = SharedDefaults.shared.get(.identity) else {
            throw NotificationServiceError.missingIdentityInDefaults
        }
        
        guard let ciphertext = notificationInfo.encryptedMessage.ciphertext else {
            return nil
        }

        let tokenCallback: EThree.RenewJwtCallback = { callback in
            // Should not happen
            fatalError("Callback called from notification")
        }
        
        let params = try Virgil.getDefaultE3KitParams(identity: identity, tokenCallback: tokenCallback)
        params.offlineInit = true
        let ethree = try EThree(params: params)

        guard let card = ethree.findCachedUser(with: notificationInfo.sender) else {
            return nil
        }
        
        guard let ratchetChannel = try ethree.getRatchetChannel(with: card) else {
            throw NotificationServiceError.ratchetChannelNotFound
        }
        
        return try ratchetChannel.decrypt(data: ciphertext, updateSession: false)
    }

    private func process(notificationInfo: NotificationInfo, decryptedData: Data?, version: EncryptedMessageVersion) throws -> String {
        let messageString: String

        switch version {
        case .v1:
            guard let decryptedData = decryptedData, let string = String(data: decryptedData, encoding: .utf8) else {
                throw NotificationServiceError.dataToStrFailed
            }

            messageString = string
        case .v2:
            guard let decryptedData = decryptedData else {
                return "Sent you new message" // FIXME: Localize
            }
            
            let message = try NetworkMessage.import(from: decryptedData)

            messageString = message.notificationBody
        }

        return messageString
    }
}
