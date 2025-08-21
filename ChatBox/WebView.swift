import UIKit
import WebKit
import ObjectiveC

func createWebView(
    container: UIView,
    messageHandler: WKScriptMessageHandler,
    navigationDelegate: WKNavigationDelegate,
    observer: NSObject
) -> WKWebView {
    
    print("[DEBUG] - [WebView] - [INFO] - [Setup]: Конфигуриране на WebView настройки")
    
    let config = WKWebViewConfiguration()
    let preferences = WKWebpagePreferences()
    let webPreferences = WKPreferences()
    
    if #available(iOS 14.0, *) {
        preferences.allowsContentJavaScript = true
    } else {
        webPreferences.javaScriptEnabled = true
    }
    
    config.preferences = webPreferences
    config.defaultWebpagePreferences = preferences
    
    let userContentController = WKUserContentController()
    config.userContentController = userContentController
    
    // Добавяме JavaScript за прихващане на console.log
    let consoleLogJS = """
    function captureLog(type, args) {
        const messages = Array.from(args).map(arg => {
            try {
                return typeof arg === 'object' ? JSON.stringify(arg) : String(arg);
            } catch {
                return String(arg);
            }
        });
        
        window.webkit.messageHandlers.console.postMessage({
            type: type,
            message: messages
        });
    }
    
    window.console.log = function() { captureLog('log', arguments); };
    window.console.error = function() { captureLog('error', arguments); };
    window.console.warn = function() { captureLog('warn', arguments); };
    window.console.info = function() { captureLog('info', arguments); };
    """
    
    let script = WKUserScript(
        source: consoleLogJS,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: false
    )
    
    userContentController.addUserScript(script)
    userContentController.add(messageHandler, name: "console")
    
    print("[DEBUG] - [WebView] - [INFO] - [Handlers]: Регистриране на обработващи функции")
    userContentController.add(messageHandler, name: "console-log")
    print("[DEBUG] - [WebView] - [INFO] - [Handler]: Регистриран apple-sign-in message handler")
    userContentController.add(messageHandler, name: "apple-sign-in")
    print("[DEBUG] - [WebView] - [INFO] - [Handler]: Регистриран facebook-login message handler")  
    userContentController.add(messageHandler, name: "facebook-login")
    userContentController.add(messageHandler, name: "purchase-completed")
    
    // Debug: List all registered handlers
    print("[DEBUG] - [WebView] - [INFO] - [Handlers]: Всички регистрирани handlers: console, console-log, apple-sign-in, facebook-login, purchase-completed")
    
    let frame = container.bounds
    let webView = WKWebView(frame: frame, configuration: config)
    
    // Добавяме extension метод за подготовка на URL
    webView.prepareUrl = { url in
        print("[DEBUG] - [WebView] - [INFO] - [URL]: Подготовка на URL с device параметри")
        
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            print("[DEBUG] - [WebView] - [ERROR] - [URL]: Невалиден URL формат")
            return url
        }
        
        // Проверяваме дали пътят завършва с "/"
        if !components.path.hasSuffix("/") {
            components.path = components.path + "/"
        }
        
        // Генерираме device ID
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        
        // Добавяме параметрите подобно на Android
        var queryItems = components.queryItems ?? []
        queryItems.append(contentsOf: [
            URLQueryItem(name: "twa_code", value: UUID().uuidString),
            URLQueryItem(name: "device_id", value: deviceId),
            URLQueryItem(name: "device_model", value: UIDevice.current.model),
            URLQueryItem(name: "device_platform", value: "ios"),
            URLQueryItem(name: "app_store", value: "apple")
        ])
        
        components.queryItems = queryItems
        
        if let finalUrl = components.url {
            print("[DEBUG] - [WebView] - [INFO] - [URL]: Подготвен URL: \(finalUrl)")
            return finalUrl
        }
        
        print("[DEBUG] - [WebView] - [ERROR] - [URL]: Грешка при подготовка на URL")
        return url
    }
    
    print("[DEBUG] - [WebView] - [INFO] - [Config]: Настройка на WebView конфигурация")
    webView.navigationDelegate = navigationDelegate
    webView.isOpaque = false
    webView.backgroundColor = .clear
    webView.scrollView.backgroundColor = .clear
    
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.insetsLayoutMarginsFromSafeArea = false
    webView.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
    
    // Добавяме наблюдател за прогреса
    webView.addObserver(observer, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
    webView.addObserver(observer, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
    
    print("[DEBUG] - [WebView] - [INFO] - [Layout]: Добавяне на WebView към контейнера")
    container.addSubview(webView)
    
    webView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        webView.topAnchor.constraint(equalTo: container.topAnchor),
        webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])
    
    // Добавяме observer за purchase completed нотификация
    NotificationCenter.default.addObserver(forName: .purchaseCompleted, object: nil, queue: .main) { _ in
        print("[DEBUG] - [WebView] - [INFO] - [Purchase]: Пренасочване към root след успешна покупка")
        let rootUrl = URL(string: "https://chatboxapp.online/")!
        webView.load(URLRequest(url: rootUrl))
    }
    
    // Добавяме observer за cancelled subscription
    NotificationCenter.default.addObserver(forName: .subscriptionCancelled, object: nil, queue: .main) { _ in
        print("[DEBUG] - [WebView] - [INFO] - [Subscription]: Пренасочване към root след отказан абонамент")
        let rootUrl = URL(string: "https://chatboxapp.online/")!
        webView.load(URLRequest(url: rootUrl))
    }
    
    print("[DEBUG] - [WebView] - [INFO] - [Complete]: WebView настройката завършена успешно")
    
    return webView
}

class MessageHandler: NSObject, WKScriptMessageHandler {
    weak var viewController: ViewController?
    
    init(viewController: ViewController) {
        self.viewController = viewController
        super.init()
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "console":
            // Подробно логване на цялото съобщение
            print("[DEBUG] - [WebView] - [RAW] - [Console]: \(message.body)")
            
            if let body = message.body as? [String: Any] {
                // Логване на целия body за debug
                print("[DEBUG] - [WebView] - [BODY] - [Console]: \(body)")
                
                if let type = body["type"] as? String,
                   let messages = body["message"] as? [String] {
                    let messageText = messages.joined(separator: " ")
                    print("[DEBUG] - [WebView] - [CONSOLE] - [\(type.uppercased())]: \(messageText)")
                } else {
                    // Ако форматът е различен, показваме raw данните
                    print("[DEBUG] - [WebView] - [ERROR] - [Console]: Неочакван формат на съобщението")
                    print("[DEBUG] - [WebView] - [ERROR] - [Console]: Raw message: \(message.body)")
                }
            }
            
        case "console-log":
            print("[DEBUG] - [WebView] - [INFO] - [Console]: Получено съобщение от JavaScript: \(message.body)")
            
        case "apple-sign-in":
            print("[DEBUG] - [WebView] - [INFO] - [Auth]: Стартиране на Apple вход")
            guard let vc = viewController else {
                print("[DEBUG] - [WebView] - [ERROR] - [Auth]: ViewController не е наличен")
                return
            }
            AppleLoginManager.shared.handleNativeAppleSignIn(
                from: vc,
                webView: ViewController.webView
            )
            
        case "purchase-completed":
            print("[DEBUG] - [WebView] - [INFO] - [Purchase]: Успешна покупка, пренасочване към root")
            if let webView = ViewController.webView {
                DispatchQueue.main.async {
                    let rootUrl = URL(string: "https://chatboxapp.online/")!
                    webView.load(URLRequest(url: rootUrl))
                }
            }
            
        default:
            print("[DEBUG] - [WebView] - [WARN] - [Message]: Неподдържан тип съобщение: \(message.name)")
        }
    }
}

class WebViewController: UIViewController {
    // Добавяме webView като property
    private var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Инициализация на webView
        webView = WKWebView(frame: view.bounds)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)
        
        // Добавяме observer за URL нотификации
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotificationURL(_:)),
            name: .openNotificationURL,
            object: nil
        )
    }
    
    @objc func handleNotificationURL(_ notification: Notification) {
        if let url = notification.userInfo?["url"] as? URL {
            // Зареждаме URL-а в WebView
            webView.load(URLRequest(url: url))
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// Добавяме extension към WKWebView за URL подготовка
private var prepareUrlKey: UInt8 = 0

extension WKWebView {
    typealias URLPreparation = (URL) -> URL
    
    var prepareUrl: URLPreparation? {
        get {
            return objc_getAssociatedObject(self, &prepareUrlKey) as? URLPreparation
        }
        set {
            objc_setAssociatedObject(self, &prepareUrlKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

// Създаваме отделна функция за зареждане с подготвен URL
func loadWithPreparedUrl(_ webView: WKWebView, _ request: URLRequest) -> WKNavigation? {
    if let url = request.url, let prepareUrl = webView.prepareUrl {
        let preparedUrl = prepareUrl(url)
        var newRequest = request
        newRequest.url = preparedUrl
        return webView.load(newRequest)
    }
    return webView.load(request)
}