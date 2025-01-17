import SwiftUI
import CoreData

struct MainTabView: View {
    let viewContext: NSManagedObjectContext
    @ObservedObject var authViewModel: AuthenticationViewModel
    
    init(viewContext: NSManagedObjectContext, authViewModel: AuthenticationViewModel) {
        self.viewContext = viewContext
        self.authViewModel = authViewModel
    }
    
    var body: some View {
        TabView {
            RealTimeMonitorView(viewContext: viewContext)
                .tabItem {
                    Label("Monitor", systemImage: "chart.xyaxis.line")
                }
            
            TriggerConfigView(viewContext: viewContext)
                .tabItem {
                    Label("Triggers", systemImage: "slider.horizontal.3")
                }
            
            ProductsView(viewContext: viewContext)
                .tabItem {
                    Label("Products", systemImage: "cart")
                }
            
            SettingsView(viewContext: viewContext, authViewModel: authViewModel)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
