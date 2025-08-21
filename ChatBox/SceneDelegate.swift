import UIKit

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("[DEBUG] - [SceneDelegate] - [INFO] - [Start]: Сцената ще се свърже със сесията")
        print("[DEBUG] - [SceneDelegate] - [INFO] - [Critical]: Започва Critical Path")
        
        guard let windowScene = (scene as? UIWindowScene) else {
            print("[DEBUG] - [SceneDelegate] - [ERROR] - [Validation]: Неуспешно преобразуване на сцената към UIWindowScene")
            return
        }
        
        // 1. Basic Window Setup
        window = UIWindow(windowScene: windowScene)
        
        // 2. Създаваме ViewController преди градиентите
        let viewController = ViewController()
        window?.rootViewController = viewController
        
        // 3. Градиенти - прилагаме ги върху view на контролера
        GradientManager.shared.configureMainGradient(for: viewController.view)
        GradientManager.shared.configureStatusBarGradient()
        print("[DEBUG] - [SceneDelegate] - [INFO] - [Critical]: Градиенти конфигурирани")
        
        // 4. Показваме прозореца
        window?.makeKeyAndVisible()
        
        print("[DEBUG] - [SceneDelegate] - [INFO] - [Critical]: Basic Window Setup завършен")
        print("[DEBUG] - [SceneDelegate] - [INFO] - [Complete]: Основната конфигурация е завършена")
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        print("[DEBUG] - [SceneDelegate] - [INFO] - [Lifecycle]: Сцената се изключи")
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        print("[DEBUG] - [SceneDelegate] - [INFO] - [Lifecycle]: Сцената стана активна")
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        print("[DEBUG] - [SceneDelegate] - [INFO] - [Lifecycle]: Сцената ще стане неактивна")
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        print("[DEBUG] - [SceneDelegate] - [INFO] - [Lifecycle]: Сцената ще премине на преден план")
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        print("[DEBUG] - [SceneDelegate] - [INFO] - [Lifecycle]: Сцената премина на заден план")
    }
}

