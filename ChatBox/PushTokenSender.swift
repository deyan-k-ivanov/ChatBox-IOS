import Foundation
import UIKit

class PushTokenSender {
    // MARK: - Singleton
    static let shared = PushTokenSender()
    private init() {}
    
    // MARK: - Constants
    private let apiUrl = "https://chatboxapp.online/api/push-notifications?case=save-token"
    
    // MARK: - Public Methods
    func sendToken(_ token: String) {
        print("[DEBUG] - [PushTokenSender] - [INFO] - [Token]: Подготовка за изпращане на токен")
        
        // Get device info
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        let deviceModel = UIDevice.current.model
        let devicePlatform = "ios"
        
        // Construct URL with parameters
        guard var urlComponents = URLComponents(string: apiUrl) else {
            print("[DEBUG] - [PushTokenSender] - [ERROR] - [URL]: Невалиден базов URL")
            return
        }
        
        // Add query parameters
        urlComponents.queryItems = [
            URLQueryItem(name: "case", value: "save-token"),
            URLQueryItem(name: "device_id", value: deviceId),
            URLQueryItem(name: "device_model", value: deviceModel),
            URLQueryItem(name: "device_platform", value: devicePlatform),
            URLQueryItem(name: "fcm_token", value: token)
        ]
        
        guard let url = urlComponents.url else {
            print("[DEBUG] - [PushTokenSender] - [ERROR] - [URL]: Грешка при създаване на URL")
            return
        }
        
        print("[DEBUG] - [PushTokenSender] - [INFO] - [Request]: URL заявка: \(url.absoluteString)")
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                self?.logError("Мрежова грешка: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self?.logError("Невалиден отговор от сървъра")
                return
            }
            
            if httpResponse.statusCode == 200 {
                if let data = data,
                   let responseString = String(data: data, encoding: .utf8) {
                    self?.logInfo("Успешен отговор: \(responseString)")
                }
            } else {
                self?.logError("Сървърът върна грешка: \(httpResponse.statusCode)")
            }
        }
        
        task.resume()
    }
    
    // MARK: - Private Methods
    private func logInfo(_ message: String) {
        print("[DEBUG] - [PushTokenSender] - [INFO] - [Push]: \(message)")
    }
    
    private func logError(_ message: String) {
        print("[DEBUG] - [PushTokenSender] - [ERROR] - [Push]: \(message)")
    }
}
