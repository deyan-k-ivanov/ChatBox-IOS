import UIKit
import AuthenticationServices
import WebKit
import CommonCrypto

class AppleLoginManager: NSObject {
    static let shared = AppleLoginManager()
    
    private var isLoginInProgress = false
    weak var viewController: UIViewController?
    weak var webView: WKWebView?
    
    func handleNativeAppleSignIn(from viewController: UIViewController, webView: WKWebView) {
        // Проверяваме дали вече тече Apple login процес
        guard !isLoginInProgress else {
            print("[DEBUG] - [AppleLogin] - [ERROR] - [Validation]: Вече тече процес на вход")
            return
        }
        
        self.viewController = viewController
        self.webView = webView
        self.isLoginInProgress = true
        
        print("[DEBUG] - [AppleLogin] - [INFO] - [Start]: Стартиране на Apple вход")
        
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email, .fullName]
        
        let nonce = String.randomNonceString()
        request.nonce = nonce.sha256()
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        
        DispatchQueue.main.async {
            controller.performRequests()
        }
        
        // Reset login state after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.isLoginInProgress = false
        }
    }
    
    private func handleAppleLoginSuccess(authCode: String, identityToken: String, userIdentifier: String) {
        guard let webView = webView else {
            print("[DEBUG] - [AppleLogin] - [ERROR] - [Validation]: WebView не е наличен")
            return
        }
        
        print("[DEBUG] - [AppleLogin] - [INFO] - [Success]: Обработка на успешен вход")
        
        // Подготвяме данните за POST заявка (като FacebookLoginManager)
        let postData = [
            "case": "apple-register",
            "code": authCode,
            "id_token": identityToken,
            "user": userIdentifier,
            "platform": "ios"
        ]
        
        // Конвертираме в JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: postData, options: []) else {
            print("[DEBUG] - [AppleLogin] - [ERROR] - [JSON]: Грешка при сериализация на данни")
            return
        }
        
        // Създаваме POST заявка към backend (unified с Facebook approach)
        let urlString = "https://chatboxapp.online/api/register"
        guard let url = URL(string: urlString) else {
            print("[DEBUG] - [AppleLogin] - [ERROR] - [URL]: Невалиден URL за регистрация")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        print("[DEBUG] - [AppleLogin] - [INFO] - [Request]: Изпращане на POST заявка към backend")
        
        // Изпращаме заявката
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[DEBUG] - [AppleLogin] - [ERROR] - [Network]: \(error.localizedDescription)")
                    return
                }
                
                // КЛЮЧОВО: Копираме session cookies от URLSession към WebView
                if let httpResponse = response as? HTTPURLResponse,
                   let url = response?.url {
                    
                    let cookies = HTTPCookie.cookies(withResponseHeaderFields: httpResponse.allHeaderFields as! [String: String], for: url)
                    print("[DEBUG] - [AppleLogin] - [INFO] - [Cookies]: Намерени \(cookies.count) cookies от backend")
                    
                    for cookie in cookies {
                        print("[DEBUG] - [AppleLogin] - [INFO] - [Cookie]: \(cookie.name) = \(cookie.value)")
                        // Добавяме всеки cookie в WebView cookie storage
                        webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
                    }
                }
                
                // Настройваме cookie за последен метод на вход
                self?.setLastLoginMethodCookie()
                
                // След копирането на cookies, зареждаме главната страница
                print("[DEBUG] - [AppleLogin] - [INFO] - [Redirect]: Зареждане на главна страница с session cookies")
                let mainUrl = URL(string: "https://chatboxapp.online/")!
                webView.load(URLRequest(url: mainUrl))
            }
        }
        
        task.resume()
    }
    
    private func setLastLoginMethodCookie() {
        let cookieProperties: [HTTPCookiePropertyKey: Any] = [
            .domain: "chatboxapp.online",
            .path: "/",
            .name: "last_login_method",
            .value: "apple",
            .secure: true,
            .expires: Date(timeIntervalSinceNow: 86400 * 30) // 30 дни
        ]
        
        if let cookie = HTTPCookie(properties: cookieProperties) {
            // Използваме WebView cookie storage (не HTTPCookieStorage) - с safe unwrap
            webView?.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
            print("[DEBUG] - [AppleLogin] - [INFO] - [Cookie]: WebView бисквитка за последен метод настроена")
        } else {
            print("[DEBUG] - [AppleLogin] - [ERROR] - [Cookie]: Грешка при създаване на бисквитка")
        }
    }
}

// MARK: - Apple Sign In Delegates
extension AppleLoginManager: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return viewController?.view.window ?? UIWindow()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("[DEBUG] - [AppleLogin] - [INFO] - [Auth]: Оторизацията е завършена")
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("[DEBUG] - [AppleLogin] - [ERROR] - [Validation]: Невалиден тип на удостоверяване")
            return
        }
        
        guard let identityToken = appleIDCredential.identityToken,
              let authCode = appleIDCredential.authorizationCode else {
            print("[DEBUG] - [AppleLogin] - [ERROR] - [Validation]: Липсват необходимите удостоверения")
            return
        }
        
        guard let identityTokenString = String(data: identityToken, encoding: .utf8),
              let authCodeString = String(data: authCode, encoding: .utf8) else {
            print("[DEBUG] - [AppleLogin] - [ERROR] - [Decode]: Грешка при декодиране на удостоверенията")
            return
        }
        
        handleAppleLoginSuccess(
            authCode: authCodeString,
            identityToken: identityTokenString,
            userIdentifier: appleIDCredential.user
        )
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("[DEBUG] - [AppleLogin] - [ERROR] - [Auth]: \(error.localizedDescription)")
        
        let errorCode = (error as NSError).code
        if errorCode == ASAuthorizationError.canceled.rawValue {
            print("[DEBUG] - [AppleLogin] - [INFO] - [Cancel]: Потребителят отказа входа")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: "Грешка при вход",
                message: "Неуспешен опит за вход с Apple. Моля, опитайте отново.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.viewController?.present(alert, animated: true)
        }
    }
}

extension String {
    func sha256() -> String {
        if let stringData = self.data(using: .utf8) {
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            stringData.withUnsafeBytes { buffer in
                _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
            }
            return hash.map { String(format: "%02x", $0) }.joined()
        }
        return ""
    }
    
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
} 