import SwiftUI
import CoreData

struct SettingsView: View {
    let viewContext: NSManagedObjectContext
    @ObservedObject var authViewModel: AuthenticationViewModel
    @StateObject private var simulatorViewModel: POSSimulatorViewModel  // Add this
    @State private var showResetAlert = false
    @State private var showSimulationResetAlert = false
    
    init(viewContext: NSManagedObjectContext, authViewModel: AuthenticationViewModel) {
        self.viewContext = viewContext
        self.authViewModel = authViewModel
        // Initialize simulator view model
        _simulatorViewModel = StateObject(wrappedValue: POSSimulatorViewModel(context: viewContext))
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("POS Simulator")) {
                    simulatorControls
                }
                
                Section(header: Text("Data Management")) {
                    Button(role: .destructive, action: {
                        showResetAlert = true
                    }) {
                        Label("Reset Product Database", systemImage: "trash")
                    }
                    
                    Button(role: .destructive, action: {
                        showSimulationResetAlert = true
                    }) {
                        Label("Reset Simulation Data", systemImage: "arrow.counterclockwise")
                    }
                }
                
                Section {
                    Button("Logout") {
                        authViewModel.logout()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .alert("Reset Products", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetProducts()
                }
            } message: {
                Text("This will delete all products. Are you sure?")
            }
            .alert("Reset Simulation", isPresented: $showSimulationResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    simulatorViewModel.resetSimulation()
                }
            } message: {
                Text("This will clear all simulation data. Are you sure?")
            }
        }
    }
    
    private var simulatorControls: some View {
        VStack(spacing: 16) {
            // Simulator Status and Controls
            HStack {
                VStack(alignment: .leading) {
                    Text("Status: \(simulatorViewModel.isRunning ? "Running" : "Stopped")")
                        .font(.subheadline)
                    Text("Speed: \(simulatorViewModel.speedMultiplier)x")
                        .font(.subheadline)
                }
                Spacer()
                HStack {
                    Button(action: { simulatorViewModel.toggleSimulation() }) {
                        Image(systemName: simulatorViewModel.isRunning ? "stop.fill" : "play.fill")
                            .foregroundColor(simulatorViewModel.isRunning ? .red : .green)
                    }
                }
            }
            
            // Speed Control
            Picker("Simulation Speed", selection: .init(
                get: { simulatorViewModel.speedMultiplier },
                set: { simulatorViewModel.setSpeed($0) }
            )) {
                Text("1x").tag(1)
                Text("5x").tag(5)
                Text("10x").tag(10)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Pattern Toggles
            Toggle("Weekend Sales Boost", isOn: .init(
                get: { simulatorViewModel.enableWeekendBoost },
                set: { simulatorViewModel.enableWeekendBoost = $0 }
            ))
            
            Toggle("Lunch Hour Rush", isOn: .init(
                get: { simulatorViewModel.enableLunchRush },
                set: { simulatorViewModel.enableLunchRush = $0 }
            ))
            
            Toggle("Payday Effect", isOn: .init(
                get: { simulatorViewModel.enablePaydayEffect },
                set: { simulatorViewModel.enablePaydayEffect = $0 }
            ))
            
            // Simulation Stats
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Sales: \(simulatorViewModel.totalSalesGenerated)")
                    .font(.caption)
                Text("Simulation Time: \(simulatorViewModel.simulationTime.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
            }
            .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
    
    private func resetProducts() {
        // First stop simulation if running
        if simulatorViewModel.isRunning {
            simulatorViewModel.toggleSimulation()
        }
        
        // Delete all products
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Product.fetchRequest()
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try viewContext.execute(batchDelete)
            try viewContext.save()
            print("✨ Product database reset complete")
        } catch {
            print("Error resetting products: \(error)")
        }
    }
}
