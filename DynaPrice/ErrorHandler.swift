import Foundation

// MARK: - Error Types
enum DynaPriceError: LocalizedError {
    case simulationError(String)
    case databaseError(String)
    case baselineError(String)
    case triggerError(String)
    case networkError(String)
    case validationError(String)
    case authenticationError(String)
    case dataImportError(String)
    
    var errorDescription: String? {
        switch self {
        case .simulationError(let message): return "Simulation Error: \(message)"
        case .databaseError(let message): return "Database Error: \(message)"
        case .baselineError(let message): return "Baseline Error: \(message)"
        case .triggerError(let message): return "Trigger Error: \(message)"
        case .networkError(let message): return "Network Error: \(message)"
        case .validationError(let message): return "Validation Error: \(message)"
        case .authenticationError(let message): return "Authentication Error: \(message)"
        case .dataImportError(let message): return "Import Error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .simulationError:
            return "Try resetting the simulation or checking product data."
        case .databaseError:
            return "Check database connection and try again."
        case .baselineError:
            return "Verify baseline data and reimport if necessary."
        case .triggerError:
            return "Review trigger configuration and try again."
        case .networkError:
            return "Check network connection and try again."
        case .validationError:
            return "Review input data and correct any errors."
        case .authenticationError:
            return "Try logging in again or contact support."
        case .dataImportError:
            return "Verify file format and try importing again."
        }
    }
}

// MARK: - Error Handler
class ErrorHandler {
    static let shared = ErrorHandler()
    private let logger = AppLogger.shared
    
    private init() {}
    
    func handle(_ error: Error, category: LogCategory, file: String = #file, function: String = #function, line: Int = #line) {
        // Log the error
        logger.error("An error occurred", category: category, error: error)
        
        // Handle specific error types
        switch error {
        case let dynaPriceError as DynaPriceError:
            handleDynaPriceError(dynaPriceError, category: category)
        case let nsError as NSError:
            handleNSError(nsError, category: category)
        default:
            handleGenericError(error, category: category)
        }
    }
    
    private func handleDynaPriceError(_ error: DynaPriceError, category: LogCategory) {
        let userInfo: [String: Any] = [
            "error": error,
            "category": category,
            "recovery": error.recoverySuggestion ?? ""
        ]
        
        switch error {
        case .simulationError:
            NotificationCenter.default.post(
                name: .simulationErrorOccurred,
                object: nil,
                userInfo: userInfo
            )
            
        case .databaseError:
            NotificationCenter.default.post(
                name: .databaseErrorOccurred,
                object: nil,
                userInfo: userInfo
            )
            
        case .baselineError:
            NotificationCenter.default.post(
                name: .baselineErrorOccurred,
                object: nil,
                userInfo: userInfo
            )
            
        default:
            NotificationCenter.default.post(
                name: .generalErrorOccurred,
                object: nil,
                userInfo: userInfo
            )
        }
    }
    
    private func handleNSError(_ error: NSError, category: LogCategory) {
        if error.domain == NSCocoaErrorDomain {
            NotificationCenter.default.post(
                name: .coreDataErrorOccurred,
                object: nil,
                userInfo: ["error": error, "category": category]
            )
        }
    }
    
    private func handleGenericError(_ error: Error, category: LogCategory) {
        NotificationCenter.default.post(
            name: .unknownErrorOccurred,
            object: nil,
            userInfo: ["error": error, "category": category]
        )
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let simulationErrorOccurred = Notification.Name("SimulationErrorOccurred")
    static let databaseErrorOccurred = Notification.Name("DatabaseErrorOccurred")
    static let baselineErrorOccurred = Notification.Name("BaselineErrorOccurred")
    static let triggerErrorOccurred = Notification.Name("TriggerErrorOccurred")
    static let generalErrorOccurred = Notification.Name("GeneralErrorOccurred")
    static let coreDataErrorOccurred = Notification.Name("CoreDataErrorOccurred")
    static let unknownErrorOccurred = Notification.Name("UnknownErrorOccurred")
}

// MARK: - Convenience Methods
extension ErrorHandler {
    func tryOrLog<T>(_ operation: String, category: LogCategory, action: () throws -> T) -> T? {
        do {
            return try action()
        } catch {
            handle(error, category: category)
            return nil
        }
    }
    
    func tryAsync<T>(_ operation: String, category: LogCategory, action: @escaping () async throws -> T) async -> T? {
        do {
            return try await action()
        } catch {
            handle(error, category: category)
            return nil
        }
    }
}
