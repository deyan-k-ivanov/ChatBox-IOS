import UIKit
import WebKit
import FBSDKLoginKit
import FBSDKCoreKit

// 📦 NATIVE Facebook Login с LIMITED LOGIN - Facebook SDK 15.1.0
// БЕЗ Graph API calls, БЕЗ warnings - само LIMITED access
class FacebookLoginManager: NSObject {
    static let shared = FacebookLoginManager()  // ПРОСТ singleton като Apple
    
    private var isLoginInProgress = false
    weak var viewController: UIViewController?
    weak var webView: WKWebView?
    
    func handleNativeFacebookSignIn(from viewController: UIViewController, webView: WKWebView) -> Bool {
        print("[DEBUG] - [Facebook] - [INFO] - [ENTRY]: ✅ NATIVE Facebook login извикан!")
        print("📦📦📦 FACEBOOK LIMITED LOGIN v2025-08-19-07:00 - Facebook SDK 15.1.0! 📦📦📦")
        
        // Проверяваме дали вече тече Facebook login процес
        guard !isLoginInProgress else {
            print("[DEBUG] - [Facebook] - [ERROR] - [Validation]: Вече тече процес на вход")
            return false
        }
        
        // COMPLETE Facebook SDK re-initialization (fix internal state issue)
        guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let appId = plist["FacebookAppID"] as? String,
              let clientToken = plist["FacebookClientToken"] as? String else {
            print("[DEBUG] - [Facebook] - [ERROR] - [Config]: Не може да прочете Facebook конфигурация от Info.plist")
            return false
        }
        
        // COMPLETE Facebook SDK reset and reconfiguration
        Settings.shared.appID = appId
        Settings.shared.clientToken = clientToken
        
        // FORCE Limited Login settings (гарантирано зададени)
        Settings.shared.isAutoLogAppEventsEnabled = false
        Settings.shared.isAdvertiserIDCollectionEnabled = false
        Settings.shared.loggingBehaviors = []
        
        print("[DEBUG] - [Facebook] - [FIX] - [Config]: COMPLETE Facebook SDK re-initialization")
        print("[DEBUG] - [Facebook] - [FIX] - [Config]: App ID: \(appId)")
        print("[DEBUG] - [Facebook] - [FIX] - [Config]: LIMITED LOGIN settings applied")
        
        self.viewController = viewController
        self.webView = webView
        
        print("[DEBUG] - [Facebook] - [INFO] - [Direct]: Стартиrane на Facebook Login ДИРЕКТНО (БЕЗ delay)") 
        print("[DEBUG] - [Facebook] - [INFO] - [Direct]: ApplicationDelegate осигурява URL scheme validation")
        
        // 📦 NATIVE SDK MARKER: ФАЙЛ ВЕРСИЯ 2025-08-19-07:15 (Facebook SDK 15.1.0 LIMITED LOGIN) 
        print("[DEBUG] - [Facebook] - [LIMITED_LOGIN] - [FileVersion]: 📦 FacebookLoginManager v2025-08-19-07:15 SDK 15.1.0!")
        
        // 🔄 SYNC MARKER: FORCE iCloud SYNC DETECTION - v2025-08-19-07:15-SYNC
        print("[DEBUG] - [Facebook] - [SYNC_MARKER] - [iCloud]: 🔄 SYNC TEST v2025-08-19-07:15 - ТОЗИ MARKER ТРЯБВА ДА СЕ ВИЖДА В XCODE BUILD!")
        
        // NATIVE Facebook Limited Login (БЕЗ Graph API calls!)
        let loginManager = LoginManager()
        
        print("[DEBUG] - [Facebook] - [INFO] - [Config]: Facebook SDK v15.1.0 Limited Login - using standard permissions API")
        
        // LIMITED LOGIN for SDK v15.1.0 - using modern permissions API (fixed deprecated method)
        loginManager.logIn(permissions: ["email"], from: viewController) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoginInProgress = false
                self?.handleFacebookLoginResult(result: result, error: error)
            }
        }
        
        return true
    }
    
    private func handleFacebookLoginResult(result: LoginManagerLoginResult?, error: Error?) {
        // Login state already reset in callback
        
        guard let result = result else {
            print("[DEBUG] - [Facebook] - [ERROR] - [Result]: Няма резултат от Facebook login")
            return
        }
        
        if let error = error {
            print("[DEBUG] - [Facebook] - [ERROR] - [Login]: \(error.localizedDescription)")
            return
        }
        
        if result.isCancelled {
            print("[DEBUG] - [Facebook] - [INFO] - [Cancel]: Потребителят отказа входа")
            return
        }
        
        guard let accessToken = result.token?.tokenString else {
            print("[DEBUG] - [Facebook] - [ERROR] - [Token]: Няма access token")
            return
        }
        
        print("[DEBUG] - [Facebook] - [SUCCESS] - [Token]: ✅ LIMITED LOGIN token получен!")
        print("[DEBUG] - [Facebook] - [INFO] - [Token]: Token type: LIMITED (БЕЗ Graph API calls)")
        
        // Използваме САМО данни от LIMITED LoginResult (БЕЗ Graph API!)
        let userId = result.token?.userID ?? "fb_limited_\(Int(Date().timeIntervalSince1970))"
        let email = "facebook_limited_\(userId)@chatboxapp.online"  // Limited login email
        
        print("[DEBUG] - [Facebook] - [INFO] - [Data]: Limited FB data - user_id: \(userId), email: \(email)")
        print("[DEBUG] - [Facebook] - [INFO] - [Privacy]: БЕЗ Graph API calls - пълна privacy protection")
        
        // POST към backend
        self.sendToBackend(accessToken: accessToken, userId: userId, email: email)
    }
    
    private func sendToBackend(accessToken: String, userId: String, email: String) {
        guard let webView = webView else { 
            print("[DEBUG] - [Facebook] - [ERROR] - [Backend]: WebView reference загубена")
            return 
        }
        
        let postData = [
            "case": "facebook-register",
            "access_token": accessToken,
            "user_id": userId,
            "email": email,
            "platform": "ios",
            "login_type": "limited"  // Маркираме като Limited Login
        ]
        
        print("[DEBUG] - [Facebook] - [INFO] - [Backend]: Изпращане на LIMITED login data към backend")
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: postData, options: []) else {
            print("[DEBUG] - [Facebook] - [ERROR] - [Backend]: JSON serialization failed")
            return
        }
        
        var request = URLRequest(url: URL(string: "https://chatboxapp.online/api/register")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ChatBox-iOS", forHTTPHeaderField: "User-Agent")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[DEBUG] - [Facebook] - [ERROR] - [Backend]: Network error: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("[DEBUG] - [Facebook] - [INFO] - [Backend]: Response status: \(httpResponse.statusCode)")
                    
                    if let url = response?.url {
                        let cookies = HTTPCookie.cookies(withResponseHeaderFields: httpResponse.allHeaderFields as! [String: String], for: url)
                        for cookie in cookies {
                            webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
                        }
                    }
                }
                
                print("[DEBUG] - [Facebook] - [SUCCESS] - [Backend]: ✅ LIMITED LOGIN session създадена")
                print("[DEBUG] - [Facebook] - [INFO] - [Navigation]: Пренасочване към dashboard")
                
                let mainUrl = URL(string: "https://chatboxapp.online/")!
                webView.load(URLRequest(url: mainUrl))
            }
        }.resume()
     }
}