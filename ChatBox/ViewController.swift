import UIKit
@preconcurrency import WebKit
import AuthenticationServices
import SafariServices
import AdSupport
import AppTrackingTransparency

final class ViewController: UIViewController, SFSafariViewControllerDelegate {
    
    // MARK: - Static Properties
    static weak var shared: ViewController?
    static var webView: WKWebView!
    static let allowedOrigins = ["chatboxapp.online"]
    
    // MARK: - Properties
    private var webviewView: UIView!
    private var loadingView: UIView!
    private var progressView: UIProgressView!
    private var connectionProblemView: UIImageView!
    private var htmlIsLoaded = false {
        didSet {
            print("[DEBUG] - [ViewController] - [INFO] - [HTML]: Статус на зареждане променен на: \(htmlIsLoaded)")
        }
    }
    private let defaultUrl = URL(string: "https://chatboxapp.online")!
    private var refreshControl: UIRefreshControl!
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        print("[DEBUG] - [ViewController] - [INFO] - [Lifecycle]: Стартиране на ViewDidLoad")
        print("🚀🚀🚀 VIEWCONTROLLER FORCE SYNC TEST v2025-08-18-21:25 - ТОЗИ ЛОГ ТРЯБВА ДА СЕ ВИЖДА! 🚀🚀🚀")
        
        // 1. Basic UI Setup
        print("[DEBUG] - [ViewController] - [INFO] - [UI]: Стартиране на Basic UI Setup")
        setupBasicUI()
        createViews()
        print("[DEBUG] - [ViewController] - [INFO] - [UI]: Basic UI Setup завършен")
        
        // 2. WebView Setup (паралелно с Background Services)
        print("[DEBUG] - [ViewController] - [INFO] - [WebView]: Стартиране на WebView Complete Setup")
        setupWebView()
               
        print("[DEBUG] - [ViewController] - [INFO] - [Lifecycle]: ViewDidLoad завършен")
    }
    
    private func createViews() {
        // Създаваме основните views
        webviewView = UIView()
        loadingView = UIView()
        progressView = UIProgressView(progressViewStyle: .default)
        connectionProblemView = UIImageView()
        
        // Добавяме ги към view hierarchy
        view.addSubview(webviewView)
        view.addSubview(loadingView)
        view.addSubview(progressView)
        view.addSubview(connectionProblemView)
        
        // Задаваме constraints
        webviewView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        connectionProblemView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            webviewView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webviewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webviewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webviewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Добавете constraints за останалите views според нуждите
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            connectionProblemView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            connectionProblemView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Force layout update
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    // MARK: - Setup Methods
    private func setupBasicUI() {
        ViewController.shared = self
        edgesForExtendedLayout = .all
        extendedLayoutIncludesOpaqueBars = true
        
        if #available(iOS 11.0, *) {
            view.insetsLayoutMarginsFromSafeArea = false
            additionalSafeAreaInsets = .zero
        }
        
        if let navigationController = navigationController {
            navigationController.navigationBar.isTranslucent = false
            navigationController.setNavigationBarHidden(true, animated: false)
        }
    }
    
    private func setupWebView() {
        print("[DEBUG] - [ViewController] - [INFO] - [WebView]: Започва настройка")
        
        guard let webviewContainer = webviewView else {
            print("[DEBUG] - [ViewController] - [ERROR] - [WebView]: webviewView контейнерът не е инициализиран")
            return
        }
        
        // Конфигурация
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        
        // Facebook Tracking
        if #available(iOS 14.5, *) {
            if ATTrackingManager.trackingAuthorizationStatus == .authorized {
                let fbp = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                print("[DEBUG] - [ViewController] - [INFO] - [Tracking]: Facebook Pixel ID получен: \(fbp)")
                
                // Инжектиране на FB Pixel
                let pixelScript = """
                    localStorage.setItem('_fbp', '\(fbp)');
                    if (typeof fbq !== 'undefined') {
                        fbq('init', '\(fbp)');
                        fbq('track', 'PageView');
                    }
                """
                
                let script = WKUserScript(
                    source: pixelScript,
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: true
                )
                controller.addUserScript(script)
            }
        }
        
        config.userContentController = controller
        
        // Създаване на WebView
        ViewController.webView = createWebView(
            container: webviewContainer,
            messageHandler: self,
            navigationDelegate: self,
            observer: self
        )
        
        setupWebViewConstraints()
        setupRefreshControl()
        
        DispatchQueue.main.async { [weak self] in
            self?.loadRootUrl()
        }
        
        print("[DEBUG] - [ViewController] - [INFO] - [WebView]: WebView Complete Setup завършен")
    }
    
    private func setupWebViewConstraints() {
        webviewView.addSubview(ViewController.webView)
        ViewController.webView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            ViewController.webView.topAnchor.constraint(equalTo: webviewView.topAnchor),
            ViewController.webView.leadingAnchor.constraint(equalTo: webviewView.leadingAnchor),
            ViewController.webView.trailingAnchor.constraint(equalTo: webviewView.trailingAnchor),
            ViewController.webView.bottomAnchor.constraint(equalTo: webviewView.bottomAnchor)
        ])
        
        ViewController.webView.scrollView.contentInsetAdjustmentBehavior = .never
    }
    
    private func setupRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshWebView), for: .valueChanged)
        ViewController.webView.scrollView.addSubview(refreshControl)
        ViewController.webView.scrollView.bounces = true
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    private func loadRootUrl() {
        print("[DEBUG] - [ViewController] - [INFO] - [Navigation]: Зареждане на основния URL")
        
        _ = loadWithPreparedUrl(ViewController.webView, URLRequest(url: defaultUrl))
    }

    @objc private func refreshWebView() {
        print("[DEBUG] - [ViewController] - [INFO] - [WebView]: Опресняване на съдържанието")
        if let currentUrl = ViewController.webView.url {
            _ = loadWithPreparedUrl(ViewController.webView, URLRequest(url: currentUrl))
        }
    }
}

// MARK: - WKScriptMessageHandler
extension ViewController: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        print("[DEBUG] - [ViewController] - [INFO] - [Message]: Получено съобщение: \(message.name)")
        print("[DEBUG] - [ViewController] - [INFO] - [Message]: Message body: \(message.body)")
        print("[DEBUG] - [ViewController] - [INFO] - [Message]: Timestamp: \(Date())")
        
        if message.name == "apple-sign-in" {
            print("[DEBUG] - [ViewController] - [INFO] - [Handler]: ✅ Apple handler match - извиквам AppleLoginManager")
            AppleLoginManager.shared.handleNativeAppleSignIn(
                from: self,
                webView: ViewController.webView
            )
        }
        
        if message.name == "facebook-login" {
            print("[DEBUG] - [ViewController] - [FORCE_SYNC] - [Handler]: 🚀 v2025-08-18-21:25 Facebook handler match - NATIVE FacebookLoginManager!")
            _ = FacebookLoginManager.shared.handleNativeFacebookSignIn(
                from: self,
                webView: ViewController.webView
            )
        }
        
        switch message.name {
        case "console":
            if let body = message.body as? [String: Any] {
                let type = body["type"] as? String ?? "log"
                let messages = body["message"] as? [String] ?? []
                let messageText = messages.joined(separator: " ")
                
                switch type {
                case "log":
                    print("[DEBUG] - [WebView] - [LOG]: \(messageText)")
                case "error":
                    print("[DEBUG] - [WebView] - [ERROR]: 🔴 \(messageText)")
                case "warn":
                    print("[DEBUG] - [WebView] - [WARN]: ⚠️ \(messageText)")
                case "info":
                    print("[DEBUG] - [WebView] - [INFO]: ℹ️ \(messageText)")
                default:
                    print("[DEBUG] - [WebView] - [UNKNOWN]: \(messageText)")
                }
            }
            
        case "apple-sign-in":
            // Handle apple sign in
            break
            
        case "facebook-login":
            // Handle facebook login
            break
            
        case "purchase-completed":
            // Handle purchase
            break
            
        default:
            print("[DEBUG] - [WebView] - [WARN]: Неизвестно съобщение: \(message.name)")
        }
    }
}

// MARK: - WKNavigationDelegate
extension ViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let urlString = navigationAction.request.url?.absoluteString {
            print("[DEBUG] - [ViewController] - [INFO] - [Navigation]: Започва навигация към: \(urlString)")
            
            // Проверка за социална автентикация - работи за Apple и Facebook
            if urlString.contains("/api/register") && !urlString.contains("code=") && !urlString.contains("id_token=") && !urlString.contains("access_token") {
                print("[DEBUG] - [ViewController] - [INFO] - [Auth]: Прихванат социален auth URL")
                
                // Стартираме Apple authentication (единственото което работи native в iOS)
                AppleLoginManager.shared.handleNativeAppleSignIn(from: self, webView: ViewController.webView)
                decisionHandler(.cancel)
                return
            }
            
            // Съществуващата billing логика
            if urlString.contains("/billing/") || urlString.contains("intent://chatboxapp.online/billing/") {
                print("[DEBUG] - [ViewController] - [INFO] - [Billing]: Прихванат billing URL")
                PaymentManager.shared.handleBillingURL(urlString) { _ in }
                decisionHandler(.cancel)
                return
            }
        }
        
        // Проверяваме дали URL-ът е за Facebook login
        if let url = navigationAction.request.url {
            if url.absoluteString.contains("facebook.com") && url.absoluteString.contains("oauth") {
                print("[DEBUG] - [FACEBOOK_LOGIN] - [INFO] - [REDIRECT]: Отваряне в Safari: \(url)")
                
                // Отваряме в SFSafariViewController
                let safariVC = SFSafariViewController(url: url)
                safariVC.delegate = self
                safariVC.modalPresentationStyle = .fullScreen
                present(safariVC, animated: true)
                
                decisionHandler(.cancel)
                return
            }
            
            // NOTE: Facebook callback обработка премахната - FacebookLoginManager прави директна POST заявка
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[DEBUG] - [ViewController] - [INFO] - [Navigation]: Зареждането на страницата завършено")
        if let currentURL = webView.url?.absoluteString {
            print("[DEBUG] - [ViewController] - [INFO] - [URL]: Текущ URL: \(currentURL)")
        }
        
        htmlIsLoaded = true
        loadingView.isHidden = true
        progressView.isHidden = true
        refreshControl.endRefreshing()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[DEBUG] - [ViewController] - [ERROR] - [Navigation]: Грешка при навигация: \(error.localizedDescription)")
        connectionProblemView.isHidden = false
        refreshControl.endRefreshing()
    }
}

// MARK: - Observer
extension ViewController {
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            progressView.progress = Float(ViewController.webView.estimatedProgress)
        } else if keyPath == #keyPath(WKWebView.url) {
            print("[DEBUG] - [ViewController] - [INFO] - [Observer]: Засечена URL промяна: \(ViewController.webView.url?.absoluteString ?? "")")
        }
    }
}

// MARK: - Status Bar
extension ViewController {
    override var prefersStatusBarHidden: Bool {
        return false
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

// MARK: - Home Indicator
extension ViewController {
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
}

// MARK: - Handle Notification URL
extension ViewController {
    static func isValidDomainUrl(_ url: String) -> Bool {
        return allowedOrigins.contains { url.contains($0) }
    }
    
    static func handleNotificationUrl(_ url: String) {
        guard let webView = ViewController.webView else { return }
        
        DispatchQueue.main.async {
            if let urlObj = URL(string: url) {
                let request = URLRequest(url: urlObj)
                webView.load(request)
            }
        }
    }
}

// MARK: - SFSafariViewControllerDelegate
extension ViewController {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        print("[DEBUG] - [FACEBOOK_LOGIN] - [INFO] - [CLOSE]: Safari изглед затворен")
        controller.dismiss(animated: true)
    }
    
    func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo url: URL) {
        print("[DEBUG] - [FACEBOOK_LOGIN] - [INFO] - [REDIRECT]: Пренасочване към: \(url.absoluteString)")
        
        // NOTE: Facebook callback обработка премахната 
        // FacebookLoginManager прави директна POST заявка към /api/register
        // Само затваряме Safari VC
        controller.dismiss(animated: true)
    }
}