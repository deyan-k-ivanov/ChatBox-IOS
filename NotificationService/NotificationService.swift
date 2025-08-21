//
//  NotificationService.swift
//  NotificationService
//
//  Created by user938434 on 12/14/24.
//

import UserNotifications
import UIKit

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        NSLog("[DEBUG] - [NotificationService] - [INFO] - [Notification]: Получена нотификация")
        NSLog("[DEBUG] - [NotificationService] - [INFO] - [Payload]: \(request.content.userInfo)")
        
        let userInfo = request.content.userInfo
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent,
           let profilePictureURL = userInfo["profile_picture"] as? String,
           let senderId = userInfo["sender_id"] as? String {
            
            NSLog("[DEBUG] - [NotificationService] - [INFO] - [Avatar URL]: \(profilePictureURL)")
            
            bestAttemptContent.threadIdentifier = senderId
            bestAttemptContent.categoryIdentifier = "chat_message"
            
            guard let url = URL(string: profilePictureURL),
                  let imageData = try? Data(contentsOf: url) else {
                NSLog("[DEBUG] - [NotificationService] - [ERROR] - [Avatar]: Неуспешно изтегляне на изображението")
                contentHandler(bestAttemptContent)
                return
            }
            
            NSLog("[DEBUG] - [NotificationService] - [INFO] - [Avatar]: Изтеглено изображение с размер: \(imageData.count) bytes")
            
            // Създаваме малко квадратно изображение за аватар
            guard let image = UIImage(data: imageData) else {
                NSLog("[DEBUG] - [NotificationService] - [ERROR] - [Avatar]: Неуспешно създаване на UIImage")
                contentHandler(bestAttemptContent)
                return
            }
            
            NSLog("[DEBUG] - [NotificationService] - [INFO] - [Avatar]: Оригинален размер: \(image.size)")
            
            guard let resizedImage = image.preparingThumbnail(of: CGSize(width: 100, height: 100)) else {
                NSLog("[DEBUG] - [NotificationService] - [ERROR] - [Avatar]: Неуспешно преоразмеряване")
                contentHandler(bestAttemptContent)
                return
            }
            
            NSLog("[DEBUG] - [NotificationService] - [INFO] - [Avatar]: Преоразмерено до: \(resizedImage.size)")
            
            guard let resizedData = resizedImage.jpegData(compressionQuality: 0.7) else {
                NSLog("[DEBUG] - [NotificationService] - [ERROR] - [Avatar]: Неуспешно конвертиране в JPEG")
                contentHandler(bestAttemptContent)
                return
            }
            
            NSLog("[DEBUG] - [NotificationService] - [INFO] - [Avatar]: Компресиран размер: \(resizedData.count) bytes")
            
            let tmpDirectory = FileManager.default.temporaryDirectory
            let tmpFile = tmpDirectory.appendingPathComponent("avatar_\(senderId).jpg")
            
            do {
                try resizedData.write(to: tmpFile)
                NSLog("[DEBUG] - [NotificationService] - [INFO] - [Avatar]: Записан във: \(tmpFile.path)")
                
                let options: [String: Any] = [
                    UNNotificationAttachmentOptionsTypeHintKey: "public.jpeg",
                    UNNotificationAttachmentOptionsThumbnailHiddenKey: false
                ]
                
                NSLog("[DEBUG] - [NotificationService] - [INFO] - [Avatar Options]: \(options)")
                
                let attachment = try UNNotificationAttachment(
                    identifier: "userAvatar",
                    url: tmpFile,
                    options: options
                )
                
                bestAttemptContent.attachments = [attachment]
                NSLog("[DEBUG] - [NotificationService] - [INFO] - [Avatar]: Успешно добавен attachment")
                
            } catch {
                NSLog("[DEBUG] - [NotificationService] - [ERROR] - [Avatar]: \(error.localizedDescription)")
            }
            
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        NSLog("[DEBUG] - [NotificationService] - [INFO] - [Process]: Времето за обработка изтече")
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

}
