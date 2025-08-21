import WebKit

class ConsoleLogger {
    static let shared = ConsoleLogger()
    
    func setupConsoleLogCapture(for webView: WKWebView) {
        let script = """
            function captureLog(type, args) {
                const message = Array.from(args).map(arg => {
                    if (arg instanceof Error) {
                        return `${arg.name}: ${arg.message}\n${arg.stack}`;
                    }
                    return String(arg);
                }).join(' ');
                
                window.webkit.messageHandlers.debug.postMessage({
                    type: type,
                    message: message,
                    timestamp: new Date().toISOString()
                });
            }

            console.log = function() { captureLog('log', arguments); };
            console.error = function() { captureLog('error', arguments); };
            console.warn = function() { captureLog('warn', arguments); };
            console.debug = function() { captureLog('debug', arguments); };
        """
        
        let userScript = WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        
        webView.configuration.userContentController.addUserScript(userScript)
    }
    
    func handleConsoleMessage(_ data: [String: Any]) {
        guard let type = data["type"] as? String,
              let logMessage = data["message"] as? String,
              let timestamp = data["timestamp"] as? String else {
            print("[DEBUG] - [Console] - [ERROR] - [Validation]: Невалидни данни в конзолното съобщение")
            return
        }
        
        let level: String
        switch type {
        case "error":
            level = "ERROR"
        case "warn":
            level = "WARN"
        case "debug":
            level = "DEBUG"
        default:
            level = "INFO"
        }
        
        print("[DEBUG] - [Console] - [\(level)] - [WebView]: Съобщение от JavaScript: \(logMessage)")
    }
} 