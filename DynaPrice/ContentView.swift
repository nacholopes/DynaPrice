import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authViewModel: AuthenticationViewModel
    
    init(context: NSManagedObjectContext) {
        _authViewModel = StateObject(wrappedValue: AuthenticationViewModel(context: context))
    }
    
    var body: some View {
        if authViewModel.isAuthenticated {
            MainTabView(viewContext: viewContext, authViewModel: authViewModel)
        } else {
            LoginView(authViewModel: authViewModel)
        }
    }
}
