import Foundation
import os.log

enum LogCategory: String {
    case simulation = "Simulation"
    case sales = "Sales"
    case baseline = "Baseline"
    case trigger = "Trigger"
    case database = "Database"
}

enum LogLevel: String {
    case debug = "🔍"
    case info = "ℹ️"
    case warning = "⚠️"
    case error = "❌"
    case critical = "🚨"
}

class AppLogger {
    static let shared = AppLogger()
    private let logger: Logger
    
    private init() {
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.dynaprice", category: "DynaPrice")
    }
    
    func log(_ message: String, category: LogCategory, level: LogLevel = .info, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let logMessage = """
            [\(category.rawValue)] \(level.rawValue)
            Message: \(message)
            Location: \((file as NSString).lastPathComponent):\(line) - \(function)
            \(error.map { "Error: \($0)" } ?? "")
            """
        
        switch level {
        case .debug:
            logger.debug("\(logMessage)")
        case .info:
            logger.info("\(logMessage)")
        case .warning:
            logger.warning("\(logMessage)")
        case .error, .critical:
            logger.error("\(logMessage)")
        }
        
        #if DEBUG
        print(logMessage)
        #endif
    }
}

// Convenience methods
extension AppLogger {
    func debug(_ message: String, category: LogCategory, error: Error? = nil) {
        log(message, category: category, level: .debug, error: error)
    }
    
    func info(_ message: String, category: LogCategory, error: Error? = nil) {
        log(message, category: category, level: .info, error: error)
    }
    
    func warning(_ message: String, category: LogCategory, error: Error? = nil) {
        log(message, category: category, level: .warning, error: error)
    }
    
    func error(_ message: String, category: LogCategory, error: Error? = nil) {
        log(message, category: category, level: .error, error: error)
    }
    
    func critical(_ message: String, category: LogCategory, error: Error? = nil) {
        log(message, category: category, level: .critical, error: error)
    }
}
