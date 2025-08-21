import UIKit
import WebKit

extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

class GradientManager {
    static let shared = GradientManager()
    
    static let colors = (
        primary: UIColor(hex: "#1E2028"), // bg-secondary тъмен цвят
        secondary: UIColor(red: 18/255, green: 20/255, blue: 28/255, alpha: 0.98) // rgba(18, 20, 28, 0.98)
    )
    
    private var statusBarWindow: UIWindow!
    
    func configureMainGradient(for targetView: UIView) {
        print("[DEBUG] - [Gradient] - [INFO] - [Main]: Конфигуриране на основния градиент")
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = targetView.bounds
        gradientLayer.colors = [
            GradientManager.colors.primary.cgColor,
            GradientManager.colors.secondary.cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        
        targetView.layer.insertSublayer(gradientLayer, at: 0)
        
        print("[DEBUG] - [Gradient] - [INFO] - [Main]: Основният градиент е конфигуриран успешно")
    }
    
    func configureStatusBarGradient() {
        print("[DEBUG] - [Gradient] - [INFO] - [StatusBar]: Конфигуриране на градиент за статус лентата")
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("[DEBUG] - [Gradient] - [ERROR] - [Scene]: Неуспешно получаване на window scene")
            return
        }
        
        let statusBarHeight = windowScene.statusBarManager?.statusBarFrame.height ?? 47
        let safeAreaInsets = windowScene.windows.first?.safeAreaInsets ?? .zero
        let totalHeight = max(statusBarHeight, safeAreaInsets.top)
        
        let window = UIWindow(windowScene: windowScene)
        window.frame = CGRect(
            x: 0,
            y: 0,
            width: UIScreen.main.bounds.width,
            height: totalHeight
        )
        
        window.windowLevel = .statusBar + 1
        
        let gradientView = UIView(frame: window.bounds)
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRect(
            x: 0,
            y: 0,
            width: window.bounds.width,
            height: window.bounds.height
        )
        gradientLayer.colors = [
            GradientManager.colors.primary.cgColor,
            GradientManager.colors.secondary.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
        window.addSubview(gradientView)
        window.isHidden = false
        
        self.statusBarWindow = window
        
        print("[DEBUG] - [Gradient] - [INFO] - [StatusBar]: Градиентът на статус лентата е конфигуриран успешно")
    }
} 