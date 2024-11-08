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
        print("ViewModel initialized")
        createTestUserIfNeeded() // Create test user right away
    }
    
    func login() {
        print("Login attempted with email: \(email)")
        
        // Basic validation
        guard !email.isEmpty, !password.isEmpty else {
            print("Empty fields detected")
            showError = true
            errorMessage = "Please fill in all fields"
            return
        }
        
        // Check credentials
        let request = NSFetchRequest<User>(entityName: "User")
        request.predicate = NSPredicate(format: "email == %@ AND passwordHash == %@ AND isActive == true", email, password)
        
        do {
            let users = try viewContext.fetch(request)
            print("Found \(users.count) matching users")
            
            if let user = users.first {
                print("Login successful for user: \(user.email ?? "unknown")")
                isAuthenticated = true
                showError = false
                
                // Update last login
                user.lastLogin = Date()
                try? viewContext.save()
            } else {
                print("No matching user found")
                showError = true
                errorMessage = "Invalid credentials"
            }
        } catch {
            print("Login error: \(error.localizedDescription)")
            showError = true
            errorMessage = "Login failed: \(error.localizedDescription)"
        }
    }
    
    private func createTestUserIfNeeded() {
        let request = NSFetchRequest<User>(entityName: "User")
        
        do {
            let count = try viewContext.count(for: request)
            print("Current user count: \(count)")
            
            if count == 0 {
                print("Creating test user")
                let newUser = User(context: viewContext)
                newUser.id = UUID()
                newUser.email = "admin@test.com"
                newUser.passwordHash = "admin123"
                newUser.role = "admin"
                newUser.isActive = true
                newUser.lastLogin = Date()
                
                try viewContext.save()
                print("Test user created successfully")
            }
        } catch {
            print("Error creating test user: \(error)")
        }
    }
}
