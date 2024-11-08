import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            MonitoringView()
                .tabItem {
                    Label("Monitor", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            TriggerConfigView()
                .tabItem {
                    Label("Triggers", systemImage: "slider.horizontal.3")
                }
            
            ProductsView(context: PersistenceController.shared.container.viewContext)
                .tabItem {
                    Label("Products", systemImage: "cart")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    MonitoringView()
}
