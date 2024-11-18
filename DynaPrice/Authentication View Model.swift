import Foundation
import CoreData

class AuthenticationViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isAuthenticated = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    let viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        // Load saved credentials and auto-login if they exist
        if let savedEmail = UserDefaults.standard.string(forKey: "userEmail"),
           let savedPassword = UserDefaults.standard.string(forKey: "userPassword") {
            self.email = savedEmail
            self.password = savedPassword
            login()
        }
    }
    
    func login() {
        createTestUserIfNeeded()
        
        guard !email.isEmpty, !password.isEmpty else {
            showError = true
            errorMessage = "Please fill in all fields"
            return
        }
        
        let request = NSFetchRequest<User>(entityName: "User")
        request.predicate = NSPredicate(format: "email == %@ AND passwordHash == %@ AND isActive == true", email, password)
        
        do {
            let users = try viewContext.fetch(request)
            if let _ = users.first {
                isAuthenticated = true
                showError = false
                // Save credentials
                UserDefaults.standard.set(email, forKey: "userEmail")
                UserDefaults.standard.set(password, forKey: "userPassword")
            } else {
                showError = true
                errorMessage = "Invalid credentials"
            }
        } catch {
            showError = true
            errorMessage = "Login failed: \(error.localizedDescription)"
        }
    }
    
    func logout() {
        isAuthenticated = false
        email = ""
        password = ""
        // Clear saved credentials
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "userPassword")
    }
    
    private func createTestUserIfNeeded() {
        let request = NSFetchRequest<User>(entityName: "User")
        
        do {
            let count = try viewContext.count(for: request)
            if count == 0 {
                let newUser = User(context: viewContext)
                newUser.id = UUID()
                newUser.email = "admin@test.com"
                newUser.passwordHash = "admin123"
                newUser.role = "admin"
                newUser.isActive = true
                newUser.lastLogin = Date()
                
                try viewContext.save()
            }
        } catch {
            print("Error creating test user: \(error)")
        }
    }
}
