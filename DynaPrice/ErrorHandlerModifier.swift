import SwiftUI

struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let recovery: String?
    let primaryButton: Alert.Button
    var secondaryButton: Alert.Button?
}

struct ErrorHandlingModifier: ViewModifier {
    @State private var errorAlert: ErrorAlert?
    let error: Error?
    let retryAction: (() -> Void)?
    let onDismiss: () -> Void
    
    init(error: Error?, retryAction: (() -> Void)? = nil, onDismiss: @escaping () -> Void) {
        self.error = error
        self.retryAction = retryAction
        self.onDismiss = onDismiss
    }
    
    func body(content: Content) -> some View {
        content
            .onChange(of: error?.localizedDescription) { _, newValue in
                if newValue != nil {
                    errorAlert = createAlertFor(error!)
                }
            }
            .alert(item: $errorAlert) { alert in
                if let secondaryButton = alert.secondaryButton {
                    Alert(
                        title: Text(alert.title),
                        message: Text(createMessage(alert)),
                        primaryButton: alert.primaryButton,
                        secondaryButton: secondaryButton
                    )
                } else {
                    Alert(
                        title: Text(alert.title),
                        message: Text(createMessage(alert)),
                        dismissButton: alert.primaryButton
                    )
                }
            }
    }
    
    private func createMessage(_ alert: ErrorAlert) -> String {
        if let recovery = alert.recovery {
            return "\(alert.message)\n\nSuggested Action: \(recovery)"
        }
        return alert.message
    }
    
    private func createAlertFor(_ error: Error) -> ErrorAlert {
        switch error {
        case let dynaPriceError as DynaPriceError:
            return createDynaPriceErrorAlert(dynaPriceError)
        case let nsError as NSError:
            return createNSErrorAlert(nsError)
        default:
            return createGenericErrorAlert(error)
        }
    }
    
    private func createDynaPriceErrorAlert(_ error: DynaPriceError) -> ErrorAlert {
        let buttons = createButtons(for: error)
        let message = error.localizedDescription
        
        return ErrorAlert(
            title: getTitleForError(error),
            message: message,
            recovery: error.recoverySuggestion,
            primaryButton: buttons.primary,
            secondaryButton: buttons.secondary
        )
    }
    
    private func getTitleForError(_ error: DynaPriceError) -> String {
        switch error {
        case .simulationError: return "Simulation Error"
        case .databaseError: return "Database Error"
        case .baselineError: return "Baseline Error"
        case .triggerError: return "Trigger Error"
        case .networkError: return "Network Error"
        case .validationError: return "Validation Error"
        case .authenticationError: return "Authentication Error"
        case .dataImportError: return "Import Error"
        }
    }
    
    private func createButtons(for error: DynaPriceError) -> (primary: Alert.Button, secondary: Alert.Button?) {
        switch error {
        case .simulationError, .networkError:
            return (
                primary: .default(Text("Retry")) {
                    retryAction?()
                    onDismiss()
                },
                secondary: .cancel(Text("Dismiss")) {
                    onDismiss()
                }
            )
            
        case .authenticationError:
            return (
                primary: .destructive(Text("Log Out")) {
                    onDismiss()
                },
                secondary: .cancel(Text("Try Again")) {
                    onDismiss()
                }
            )
            
        default:
            return (
                primary: .default(Text("OK")) {
                    onDismiss()
                },
                secondary: nil
            )
        }
    }
    
    private func createNSErrorAlert(_ error: NSError) -> ErrorAlert {
        ErrorAlert(
            title: "System Error",
            message: error.localizedDescription,
            recovery: nil,
            primaryButton: .default(Text("OK")) {
                onDismiss()
            }
        )
    }
    
    private func createGenericErrorAlert(_ error: Error) -> ErrorAlert {
        ErrorAlert(
            title: "Error",
            message: error.localizedDescription,
            recovery: nil,
            primaryButton: .default(Text("OK")) {
                onDismiss()
            }
        )
    }
}

extension View {
    func handleError(_ error: Error?, retryAction: (() -> Void)? = nil, onDismiss: @escaping () -> Void = {}) -> some View {
        modifier(ErrorHandlingModifier(error: error, retryAction: retryAction, onDismiss: onDismiss))
    }
}
