import WebKit
import FirebaseMessaging
  
class SubscribeMessage {
    var topic  = ""
    var eventValue = ""
    var unsubscribe = false
    struct Keys {
        static var TOPIC = "topic"
        static var UNSUBSCRIBE = "unsubscribe"
        static var EVENTVALUE = "eventValue"
    }
    convenience init(dict: Dictionary<String,Any>) {
        self.init()
        if let topic = dict[Keys.TOPIC] as? String {
            self.topic = topic
        }
        if let unsubscribe = dict[Keys.UNSUBSCRIBE] as? Bool {
            self.unsubscribe = unsubscribe
        }
        if let eventValue = dict[Keys.EVENTVALUE] as? String {
            self.eventValue = eventValue
        }
    }
}

func handleSubscribeTouch(message: WKScriptMessage) {
    let subscribeMessages = parseSubscribeMessage(message: message)
    if (subscribeMessages.count > 0){
        let _message = subscribeMessages[0]
        if (_message.unsubscribe) {
            print("[DEBUG] - [Push] - [INFO] - [Subscribe]: Отписване от тема: \(_message.topic)")
            Messaging.messaging().unsubscribe(fromTopic: _message.topic) { error in 
                if let error = error {
                    print("[DEBUG] - [Push] - [ERROR] - [Subscribe]: Грешка при отписване от тема: \(error)")
                }
            }
        }
        else {
            print("[DEBUG] - [Push] - [INFO] - [Subscribe]: Абониране за тема: \(_message.topic)")
            Messaging.messaging().subscribe(toTopic: _message.topic) { error in 
                if let error = error {
                    print("[DEBUG] - [Push] - [ERROR] - [Subscribe]: Грешка при абониране за тема: \(error)")
                }
            }
        }
    }
}

func parseSubscribeMessage(message: WKScriptMessage) -> [SubscribeMessage] {
    var subscribeMessages = [SubscribeMessage]()
    if let objStr = message.body as? String {

        let data: Data = objStr.data(using: .utf8)!
        do {
            let jsObj = try JSONSerialization.jsonObject(with: data, options: .init(rawValue: 0))
            if let jsonObjDict = jsObj as? Dictionary<String, Any> {
                let subscribeMessage = SubscribeMessage(dict: jsonObjDict)
                subscribeMessages.append(subscribeMessage)
            } else if let jsonArr = jsObj as? [Dictionary<String, Any>] {
                for jsonObj in jsonArr {
                    let sMessage = SubscribeMessage(dict: jsonObj)
                    subscribeMessages.append(sMessage)
                }
            }
        } catch _ {
            
        }
    }
    return subscribeMessages
}

func returnPermissionResult(isGranted: Bool){
    DispatchQueue.main.async {
        if (isGranted){
            ViewController.webView.evaluateJavaScript("this.dispatchEvent(new CustomEvent('push-permission-request', { detail: 'granted' }))")
        }
        else {
            ViewController.webView.evaluateJavaScript("this.dispatchEvent(new CustomEvent('push-permission-request', { detail: 'denied' }))")
        }
    }
}
func returnPermissionState(state: String){
    DispatchQueue.main.async {
        ViewController.webView.evaluateJavaScript("this.dispatchEvent(new CustomEvent('push-permission-state', { detail: '\(state)' }))")
    }
}

func handlePushPermission() {
    UNUserNotificationCenter.current().getNotificationSettings () { settings in
        switch settings.authorizationStatus {
        case .notDetermined:
            print("[DEBUG] - [Push] - [INFO] - [Permission]: Заявка за разрешение за известия")
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: { (success, error) in
                    if error == nil {
                        if success == true {
                            print("[DEBUG] - [Push] - [INFO] - [Permission]: Разрешението е предоставено")
                            returnPermissionResult(isGranted: true)
                            DispatchQueue.main.async {
                                UIApplication.shared.registerForRemoteNotifications()
                            }
                        }
                        else {
                            print("[DEBUG] - [Push] - [WARN] - [Permission]: Разрешението е отказано от потребителя")
                            returnPermissionResult(isGranted: false)
                        }
                    }
                    else {
                        print("[DEBUG] - [Push] - [ERROR] - [Permission]: Грешка при заявка за разрешение: \(error!)")
                        returnPermissionResult(isGranted: false)
                    }
                }
            )
        case .denied:
            print("[DEBUG] - [Push] - [WARN] - [Permission]: Известията са отказани")
            returnPermissionResult(isGranted: false)
        case .authorized, .ephemeral, .provisional:
            print("[DEBUG] - [Push] - [INFO] - [Permission]: Известията са разрешени")
            returnPermissionResult(isGranted: true)
        @unknown default:
            print("[DEBUG] - [Push] - [WARN] - [Permission]: Неизвестен статус на разрешение")
            return;
        }
    }
}
func handlePushState() {
    UNUserNotificationCenter.current().getNotificationSettings () { settings in
        switch settings.authorizationStatus {
        case .notDetermined:
            returnPermissionState(state: "notDetermined")
        case .denied:
            returnPermissionState(state: "denied")
        case .authorized:
            returnPermissionState(state: "authorized")
        case .ephemeral:
            returnPermissionState(state: "ephemeral")
        case .provisional:
            returnPermissionState(state: "provisional")
        @unknown default:
            returnPermissionState(state: "unknown")
            return;
        }
    }
}

func checkViewAndEvaluate(event: String, detail: String) {
    if (!ViewController.webView.isHidden && !ViewController.webView.isLoading ) {
        DispatchQueue.main.async {
            ViewController.webView.evaluateJavaScript("this.dispatchEvent(new CustomEvent('\(event)', { detail: \(detail) }))")
        }
    }
    else {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            checkViewAndEvaluate(event: event, detail: detail)
        }
    }
}

func handleFCMToken(){
    DispatchQueue.main.async {
        Messaging.messaging().token { token, error in
            if let error = error {
                print("[DEBUG] - [Push] - [ERROR] - [Token]: Грешка при получаване на FCM токен: \(error)")
                checkViewAndEvaluate(event: "push-token", detail: "ERROR GET TOKEN")
            } else if let token = token {
                print("[DEBUG] - [Push] - [INFO] - [Token]: Получен FCM токен: \(token)")
                checkViewAndEvaluate(event: "push-token", detail: "'\(token)'")
            }
        }   
    }
}

func sendPushToWebView(userInfo: [AnyHashable: Any]){
    var json = "";
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: userInfo)
        json = String(data: jsonData, encoding: .utf8)!
    } catch {
        print("[DEBUG] - [Push] - [ERROR] - [Parse]: Грешка при обработка на userInfo данните")
        return
    }
    checkViewAndEvaluate(event: "push-notification", detail: json)
}
