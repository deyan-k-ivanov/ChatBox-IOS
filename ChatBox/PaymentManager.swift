import StoreKit
import UIKit

// MARK: - Payment Status
enum PaymentStatus {
    case success
    case failed(Error)
}

// MARK: - Payment Manager
final class PaymentManager: NSObject {
    
    // MARK: - Properties
    static let shared = PaymentManager()
    
    private let BASE_URL = "https://chatboxapp.online/api/payments"
    private var products: [SKProduct] = []
    private var completion: ((PaymentStatus) -> Void)?
    
    // За предотвратяване на дублирани транзакции
    private var lastProcessedOrderId: String?
    private let lock = NSLock()
    
    // MARK: - Initialization
    private override init() {
        super.init()
        print("[DEBUG] - [PaymentManager] - [INFO] - [Init]: Инициализация на PaymentManager")
    }
    
    // MARK: - Setup
    func setup() {
        print("[DEBUG] - [PaymentManager] - [INFO] - [Setup]: Конфигуриране на payment система")
        SKPaymentQueue.default().add(self)
        fetchProducts()
    }
    
    // MARK: - Product Management
    private func fetchProducts() {
        print("[DEBUG] - [PaymentManager] - [INFO] - [Products]: Зареждане на продукти")
        let request = SKProductsRequest(productIdentifiers: Set(["premium_monthly_membership"]))
        request.delegate = self
        request.start()
    }
    
    // MARK: - URL Handling
    func handleBillingURL(_ urlString: String, completion: @escaping (PaymentStatus) -> Void) {
        print("[DEBUG] - [PaymentManager] - [INFO] - [URL]: Обработка на URL: \(urlString)")
        
        if urlString.contains("/billing/manage") {
            print("[DEBUG] - [PaymentManager] - [INFO] - [URL]: Отваряне на настройки за абонамент")
            if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            completion(.success)
            return
        }
        
        if urlString.contains("/billing/subscribe") {
            print("[DEBUG] - [PaymentManager] - [INFO] - [URL]: Стартиране на проверка за абонамент")
            makePurchase(completion: completion)
        }
    }
    
    // MARK: - Purchase Management
    private func makePurchase(completion: @escaping (PaymentStatus) -> Void) {
        guard let product = products.first else {
            print("[Manager] - [ERROR] - [Purchase]: Няма налични продукти")
            completion(.failed(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Няма налични продукти"])))
            return
        }
        
        self.completion = completion
        SKPaymentQueue.default().add(SKPayment(product: product))
    }
    
    // MARK: - Server Communication
    private func sendPurchaseToServer(transaction: SKPaymentTransaction, product: SKProduct) {
        // Проверяваме за грешка paymentNotAllowed
        if let error = transaction.error as? SKError, 
           error.code == .paymentNotAllowed {
            print("[DEBUG] - [PaymentManager] - [StoreKit] - [Check]: Открит активен абонамент, прекратяване на транзакция")
            completion?(.success)
            return
        }
        
        // Проверка за дублирани транзакции
        lock.lock()
        let orderId = transaction.transactionIdentifier ?? ""
        if orderId == lastProcessedOrderId {
            print("[DEBUG] - [PaymentManager] - [INFO] - [Transaction]: Пропускане на дублирана транзакция: \(orderId)")
            lock.unlock()
            return
        }
        lastProcessedOrderId = orderId
        lock.unlock()
        
        print("[DEBUG] - [PaymentManager] - [INFO] - [Send]: Изпращане на покупка към сървъра")
        
        let parameters: [String: String] = [
            "case": "save-purchase",
            "productId": product.productIdentifier,
            "purchaseToken": transaction.transactionIdentifier ?? "",
            "orderId": orderId,
            "purchaseTime": "\(Int(transaction.transactionDate?.timeIntervalSince1970 ?? 0))",
            "device_id": UIDevice.current.identifierForVendor?.uuidString ?? "",
            "platform": "ios"
        ]
        
        var request = URLRequest(url: URL(string: BASE_URL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("[DEBUG] - [PaymentManager] - [ERROR] - [Server]: \(error.localizedDescription)")
                self?.completion?(.failed(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("[DEBUG] - [PaymentManager] - [INFO] - [Response]: Статус код: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    print("[DEBUG] - [PaymentManager] - [INFO] - [Success]: Успешно валидирана покупка")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("[DEBUG] - [PaymentManager] - [INFO] - [Response]: \(responseString)")
                    }
                    
                    // Изпращаме нотификация за успешна покупка
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .purchaseCompleted, object: nil)
                    }
                    
                    self?.completion?(.success)
                } else {
                    print("[DEBUG] - [PaymentManager] - [ERROR] - [Server]: Невалиден статус код")
                    self?.completion?(.failed(NSError(domain: "", code: httpResponse.statusCode)))
                }
            }
        }.resume()
    }
    
    // MARK: - Receipt Validation
    func validateReceipt() {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            print("[DEBUG] - [PaymentManager] - [ERROR] - [Receipt]: Липсва рецейт")
            return
        }
        
        guard let receiptData = try? Data(contentsOf: receiptURL).base64EncodedString() else {
            print("[DEBUG] - [PaymentManager] - [ERROR] - [Receipt]: Невалиден рецейт")
            return
        }
        
        // Първо проверяваме в production
        verifyReceipt(receiptData, isProduction: true) { [weak self] result in
            switch result {
            case .success:
                print("[DEBUG] - [PaymentManager] - [INFO] - [Receipt]: Валиден production рецейт")
            case .failure(let error as NSError):
                if error.code == 21007 { // Sandbox receipt
                    // Пробваме със sandbox
                    self?.verifyReceipt(receiptData, isProduction: false) { result in
                        print("[DEBUG] - [PaymentManager] - [INFO] - [Receipt]: Проверка в sandbox")
                    }
                }
            }
        }
    }
    
    private func verifyReceipt(_ receipt: String, isProduction: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        let verifyURL = isProduction ? 
            "https://buy.itunes.apple.com/verifyReceipt" : 
            "https://sandbox.itunes.apple.com/verifyReceipt"
        
        var request = URLRequest(url: URL(string: verifyURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["receipt-data": receipt]
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? Int else {
                completion(.failure(NSError(domain: "", code: -1)))
                return
            }
            
            if status == 0 {
                completion(.success(()))
            } else if status == 21007 {
                completion(.failure(NSError(domain: "", code: 21007)))
            } else {
                completion(.failure(NSError(domain: "", code: status)))
            }
        }.resume()
    }
    
    // MARK: - Restore Purchases
    func restorePurchases(completion: @escaping (Result<Void, Error>) -> Void) {
        print("[DEBUG] - [PaymentManager] - [INFO] - [Restore]: Започване на възстановяване")
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        print("[DEBUG] - [PaymentManager] - [INFO] - [Restore]: Успешно възстановяване")
        validateReceipt()
    }
    
    // MARK: - Subscription Status
    func checkSubscriptionStatus(completion: @escaping (Bool) -> Void) {
        validateReceipt()
        // Проверка в сървъра
        let parameters: [String: String] = [
            "case": "check-subscription",
            "device_id": UIDevice.current.identifierForVendor?.uuidString ?? "",
            "platform": "ios"
        ]
        
        var request = URLRequest(url: URL(string: BASE_URL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let isActive = json["is_active"] as? Bool {
                completion(isActive)
            } else {
                completion(false)
            }
        }.resume()
    }
}

// MARK: - SKProductsRequestDelegate
extension PaymentManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        print("[DEBUG] - [PaymentManager] - [INFO] - [Products]: Получени \(response.products.count) продукта")
        self.products = response.products
    }
}

// MARK: - SKPaymentTransactionObserver
extension PaymentManager: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        transactions.forEach { transaction in
            print("[DEBUG] - [PaymentManager] - [StoreKit] - [Response]: Получен отговор от StoreKit")
            print("[DEBUG] - [PaymentManager] - [StoreKit] - [State]: \(transaction.transactionState.rawValue)")
            
            if let error = transaction.error as? SKError {
                print("[DEBUG] - [PaymentManager] - [StoreKit] - [Error]: Код: \(error.code.rawValue)")
                print("[DEBUG] - [PaymentManager] - [StoreKit] - [Error]: Съобщение: \(error.localizedDescription)")
            }
            
            switch transaction.transactionState {
            case .purchased:
                print("[DEBUG] - [PaymentManager] - [INFO] - [Transaction]: Успешна покупка")
                print("[DEBUG] - [PaymentManager] - [StoreKit] - [Details]: ID: \(transaction.transactionIdentifier ?? "none")")
                print("[DEBUG] - [PaymentManager] - [StoreKit] - [Details]: Дата: \(transaction.transactionDate?.description ?? "none")")
                
                if let product = products.first {
                    sendPurchaseToServer(transaction: transaction, product: product)
                }
                queue.finishTransaction(transaction)
                
            case .failed:
                print("[DEBUG] - [PaymentManager] - [INFO] - [Transaction]: Прекратена транзакция")
                if let error = transaction.error as? SKError {
                    switch error.code {
                    case .paymentCancelled:
                        print("[DEBUG] - [PaymentManager] - [StoreKit] - [Result]: Потребителят отказа покупката")
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .subscriptionCancelled, object: nil)
                        }
                    case .paymentNotAllowed:
                        print("[DEBUG] - [PaymentManager] - [StoreKit] - [Result]: Вече има активен абонамент")
                    case .paymentInvalid:
                        print("[DEBUG] - [PaymentManager] - [StoreKit] - [Result]: Невалидна транзакция")
                    case .clientInvalid:
                        print("[DEBUG] - [PaymentManager] - [StoreKit] - [Result]: Клиентът не е оторизиран")
                    default:
                        print("[DEBUG] - [PaymentManager] - [StoreKit] - [Result]: Друга грешка: \(error.localizedDescription)")
                    }
                }
                completion?(.failed(transaction.error ?? NSError()))
                queue.finishTransaction(transaction)
                
            case .purchasing:
                print("[DEBUG] - [PaymentManager] - [INFO] - [Transaction]: В процес на покупка")
                print("[DEBUG] - [PaymentManager] - [StoreKit] - [Details]: Продукт: \(transaction.payment.productIdentifier)")
                
            case .restored:
                print("[DEBUG] - [PaymentManager] - [StoreKit] - [Result]: Възстановена покупка")
                if let product = products.first {
                    sendPurchaseToServer(transaction: transaction, product: product)
                }
                validateReceipt()
                queue.finishTransaction(transaction)
                
            case .deferred:
                print("[DEBUG] - [PaymentManager] - [StoreKit] - [Result]: Отложена покупка")
                
            @unknown default:
                print("[DEBUG] - [PaymentManager] - [StoreKit] - [Result]: Неизвестен статус: \(transaction.transactionState.rawValue)")
                queue.finishTransaction(transaction)
            }
        }
    }
}

extension Notification.Name {
    static let purchaseCompleted = Notification.Name("purchaseCompleted")
    static let subscriptionCancelled = Notification.Name("subscriptionCancelled")
}


