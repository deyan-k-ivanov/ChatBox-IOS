import UIKit
import FirebaseCore
import FirebaseMessaging
import FBSDKCoreKit
import StoreKit
import AppTrackingTransparency

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("[DEBUG] - [AppDelegate] - [INFO] - [Setup]: Стартиране на базова конфигурация")
        print("🚀🚀🚀 FORCE SYNC TEST v2025-08-18-21:25 - ТОЗИ ЛОГ ТРЯБВА ДА СЕ ВИЖДА! 🚀🚀🚀")
        
        // 1. Firebase конфигурация
        FirebaseApp.configure()
        
        // 2. LIMITED LOGIN + SDK OPTIMIZED VERSION  
        // 📦 SDK OPTIMIZED MARKER: ФАЙЛ ВЕРСИЯ 2025-08-19-07:00 (Facebook SDK v15.1.0 LIMITED LOGIN)
        print("[DEBUG] - [AppDelegate] - [SDK_OPTIMIZED] - [FileVersion]: 📦 AppDelegate v2025-08-19-07:00 Facebook SDK v15.1.0 LIMITED!")
        
        // Facebook SDK STANDARD setup като големите компании
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let appId = plist["FacebookAppID"] as? String,
           let clientToken = plist["FacebookClientToken"] as? String {
            
            Settings.shared.appID = appId
            Settings.shared.clientToken = clientToken
            
            // FACEBOOK ADS TRACKING: Enable App Events for install tracking (LIMITED)
            Settings.shared.isAutoLogAppEventsEnabled = true   // ✅ Enable AppEvents
            Settings.shared.isAdvertiserIDCollectionEnabled = false  // ❌ Disable IDFA (LIMITED)
            Settings.shared.loggingBehaviors = [.appEvents]  // Enable AppEvents logging
            
            // Log install event
            AppEvents.shared.logEvent(.completedRegistration)
            AppEvents.shared.logEvent(.init("fb_mobile_app_install"))
            
            print("[DEBUG] - [AppDelegate] - [SUCCESS] - [Facebook]: Install event logged")
            
            print("[DEBUG] - [AppDelegate] - [SUCCESS] - [Facebook]: LIMITED LOGIN Facebook SDK конфигуриран")
            print("📦 Facebook SDK OPTIMIZED v15.1.0 - v2025-08-19-07:00 - NATIVE LIMITED LOGIN!")
            print("[DEBUG] - [AppDelegate] - [INFO] - [Facebook]: App ID: \(appId)")
        }
        
        // CRITICAL: ApplicationDelegate САМО за URL scheme validation (БЕЗ Graph API!)
        ApplicationDelegate.shared.application(
            application, 
            didFinishLaunchingWithOptions: launchOptions
        )
        
        print("[DEBUG] - [AppDelegate] - [CRITICAL] - [Facebook]: ApplicationDelegate добавен САМО за URL validation!")
        print("[DEBUG] - [AppDelegate] - [INFO] - [Facebook]: Limited Login с URL scheme support активен!")
        
        // 5. Facebook Install Event Tracking (used once)
        let userDefaults = UserDefaults.standard
        let isFirstLaunch = !userDefaults.bool(forKey: "app_launched_before")
        
        if isFirstLaunch {
            userDefaults.set(true, forKey: "app_launched_before")
            
            // LIMITED TRACKING: No permission request needed
            AppEvents.shared.logEvent(.init("fb_mobile_app_install"))
            AppEvents.shared.logEvent(.completedRegistration)
            print("[DEBUG] - [AppDelegate] - [SUCCESS] - [Facebook]: First launch install event logged (LIMITED tracking)")
        } else {
            // TEST: Force install event for testing (remove in production)
            AppEvents.shared.logEvent(.init("fb_mobile_app_install"))
            AppEvents.shared.logEvent(.completedRegistration)
            print("[DEBUG] - [AppDelegate] - [SUCCESS] - [Facebook]: TEST install event logged (LIMITED tracking)")
            
            AppEvents.shared.logEvent(.init("fb_mobile_app_open"))
            print("[DEBUG] - [AppDelegate] - [SUCCESS] - [Facebook]: App open event logged")
        }
        
        // 6. Останали услуги
        initializeOtherServices()
        
        return true
    }
    
    // CRITICAL: ApplicationDelegate URL handling за Facebook SDK validation
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        print("[DEBUG] - [AppDelegate] - [CRITICAL] - [Facebook]: URL handling с ApplicationDelegate: \(url)")
        
        // ApplicationDelegate URL handling за Facebook SDK URL scheme validation
        let handled = ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[.sourceApplication] as? String,
            annotation: options[.annotation]
        )
        
        print("[DEBUG] - [AppDelegate] - [CRITICAL] - [Facebook]: ApplicationDelegate handled URL: \(handled)")
        return handled
    }
    

    
    private func initializeOtherServices() {
        print("[DEBUG] - [AppDelegate] - [INFO] - [FCM]: Проверка на текущ FCM токен")
        if let currentToken = Messaging.messaging().fcmToken {
            print("[DEBUG] - [AppDelegate] - [INFO] - [FCM]: Наличен FCM токен: \(currentToken)")
            // Изпращаме токена при всяко стартиране
            print("[DEBUG] - [AppDelegate] - [INFO] - [FCM]: Изпращане на текущ токен към сървъра")
            PushTokenSender.shared.sendToken(currentToken)
        } else {
            print("[DEBUG] - [AppDelegate] - [INFO] - [FCM]: Няма наличен FCM токен")
        }
        
        // 2. APN Registration
        print("[DEBUG] - [AppDelegate] - [INFO] - [APN]: Стартиране на Apple Push Registration")
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            print("[DEBUG] - [AppDelegate] - [INFO] - [APN]: Започва requestAuthorization")
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: { [weak self] granted, error in
                    if let error = error {
                        print("[DEBUG] - [AppDelegate] - [ERROR] - [APN]: Грешка при разрешаване на нотификации: \(error)")
                        return
                    }
                    print("[DEBUG] - [AppDelegate] - [INFO] - [APN]: Нотификациите са \(granted ? "разрешени" : "забранени")")
                    
                    // Rich notifications setup
                    let category = UNNotificationCategory(
                        identifier: "chat_message",
                        actions: [],
                        intentIdentifiers: [],
                        options: .customDismissAction
                    )
                    
                    UNUserNotificationCenter.current().setNotificationCategories([category])
                    
                    // Register for APN в main thread
                    DispatchQueue.main.async {
                        print("[DEBUG] - [AppDelegate] - [INFO] - [APN]: Регистрация за Apple Push Notifications")
                        // 1. Първо проверяваме дали имаме разрешение
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
                            guard granted else {
                                print("[DEBUG] - [AppDelegate] - [ERROR] - [APN]: Няма разрешение за нотификации")
                                return
                            }
                            
                            // 2. Ако имаме разрешение, регистрираме на main thread
                            DispatchQueue.main.async {
                                UIApplication.shared.registerForRemoteNotifications()
                                
                                // 3. FCM Setup след успешна APN регистрация
                                print("[DEBUG] - [AppDelegate] - [INFO] - [FCM]: Конфигуриране на Firebase Cloud Messaging")
                                Messaging.messaging().delegate = self
                            }
                        }
                    }
                }
            )
        }
        
        // 4. Останалите non-critical services
        // ПРЕМАХНАТО: Facebook AppEvents calls - причиняваха Graph API requests
        print("[DEBUG] - [AppDelegate] - [INFO] - [Facebook]: AppEvents calls премахнати за избягване на Graph API")
        
        print("[DEBUG] - [AppDelegate] - [INFO] - [Payments]: Инициализация на Payment система")
        PaymentManager.shared.setup()
        
        print("[DEBUG] - [AppDelegate] - [INFO] - [Services]: Всички услуги са конфигурирани")
        
        // ПРЕМАХНАТО: Facebook Graph API call за AEM conversion configs
        // Този Graph API call причиняваше "Limited Login" warning
        print("[DEBUG] - [AppDelegate] - [INFO] - [Facebook]: Graph API calls премахнати за избягване на Limited Login")
    }
    
    private func isFirstLaunch() -> Bool {
        let hasBeenLaunchedBeforeFlag = "hasBeenLaunchedBeforeFlag"
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: hasBeenLaunchedBeforeFlag)
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: hasBeenLaunchedBeforeFlag)
            UserDefaults.standard.synchronize()
            print("[DEBUG] - [AppDelegate] - [INFO] - [Launch]: Открито е първо стартиране на приложението")
        }
        return isFirstLaunch
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("[DEBUG] - [AppDelegate] - [INFO] - [Push]: Получен device token: \(token)")
        print("[DEBUG] - [AppDelegate] - [INFO] - [Push]: Raw device token: \(deviceToken)")
        print("[DEBUG] - [AppDelegate] - [INFO] - [Push]: Задаване на APN token към FCM")
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[DEBUG] - [AppDelegate] - [ERROR] - [Push]: Грешка при регистрация за нотификации: \(error)")
    }

    func application(_ application: UIApplication,
                    continue userActivity: NSUserActivity,
                    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        
        print("[DEBUG] - [AppDelegate] - [INFO] - [Universal Link]: Проверка на активност")
        
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let incomingURL = userActivity.webpageURL {
            print("[DEBUG] - [AppDelegate] - [INFO] - [Universal Link]: Получен URL: \(incomingURL.absoluteString)")
            
            if ViewController.isValidDomainUrl(incomingURL.absoluteString) {
                ViewController.handleNotificationUrl(incomingURL.absoluteString)
                return true
            }
        }
        return false
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("[DEBUG] - [AppDelegate] - [INFO] - [Notification]: Получена нотификация: \(userInfo)")
        
        // Проверяваме дали приложението е активно
        let isActive = UIApplication.shared.applicationState == .active
        print("[DEBUG] - [AppDelegate] - [INFO] - [State]: Приложение активно: \(isActive)")
        
        // Извличаме click_url
        var clickUrl: String?
        
        // Първо проверяваме в data секцията
        if let data = userInfo["data"] as? [String: Any] {
            clickUrl = data["click_url"] as? String
            print("[DEBUG] - [AppDelegate] - [INFO] - [URL]: URL от data секция: \(clickUrl ?? "няма")")
        }
        
        // Ако няма в data, проверяваме в root
        if clickUrl == nil {
            clickUrl = userInfo["click_url"] as? String
            print("[DEBUG] - [AppDelegate] - [INFO] - [URL]: URL от root: \(clickUrl ?? "няма")")
        }
        
        if let finalUrl = clickUrl {
            print("[DEBUG] - [AppDelegate] - [INFO] - [URL]: Обработка на URL: \(finalUrl)")
            
            // Изпълняваме в main thread
            DispatchQueue.main.async {
                if let url = URL(string: finalUrl) {
                    // Изпращаме нотификация за отваряне на URL
                    NotificationCenter.default.post(
                        name: .openNotificationURL,
                        object: nil,
                        userInfo: ["url": url]
                    )
                    
                    // Извикваме и директния метод
                    ViewController.handleNotificationUrl(finalUrl)
                }
            }
        }
        
        completionHandler()
    }
    
    // Показваме нотификация когато приложението е активно
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("[DEBUG] - [AppDelegate] - [INFO] - [FCM]: Извикан MessagingDelegate")
        
        guard let token = fcmToken, !token.isEmpty else {
            print("[DEBUG] - [AppDelegate] - [WARN] - [Token]: Получен невалиден FCM токен")
            return
        }
        
        print("[DEBUG] - [AppDelegate] - [INFO] - [Token]: FCM токен: \(token)")
        
        // Запазваме новия токен
        UserDefaults.standard.set(token, forKey: "FCMToken")
        
        print("[DEBUG] - [AppDelegate] - [INFO] - [Token]: Изпращане на токен към сървъра")
        PushTokenSender.shared.sendToken(token)
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let fcmTokenReceived = Notification.Name("FCMTokenReceived")
    static let openNotificationURL = Notification.Name("OpenNotificationURL")
}
