import SwiftUI
import CoreData

struct SettingsView: View {
    let viewContext: NSManagedObjectContext
    @ObservedObject var authViewModel: AuthenticationViewModel
    @StateObject private var simulatorViewModel: POSSimulatorViewModel
    @State private var showResetAlert = false
    @State private var selectedTrigger: PriceTrigger?
    
    // Fetch active triggers
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PriceTrigger.name, ascending: true)],
        predicate: NSPredicate(format: "active == YES"),
        animation: .default
    ) private var activeTriggers: FetchedResults<PriceTrigger>
    
    init(viewContext: NSManagedObjectContext, authViewModel: AuthenticationViewModel) {
        self.viewContext = viewContext
        self.authViewModel = authViewModel
        _simulatorViewModel = StateObject(wrappedValue: POSSimulatorViewModel(context: viewContext))
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("POS Simulator")) {
                    VStack(spacing: 16) {
                        // Start/Stop Button
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(simulatorViewModel.isRunning ? Color.red : Color.green)
                            
                            Button(action: {
                                withAnimation {
                                    simulatorViewModel.toggleSimulation()
                                }
                            }) {
                                HStack {
                                    Image(systemName: simulatorViewModel.isRunning ? "stop.fill" : "play.fill")
                                    Text(simulatorViewModel.isRunning ? "Stop Simulation" : "Start Simulation")
                                }
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 44)
                        
                        // Status Indicator
                        HStack {
                            Label("Status:", systemImage: "circle.fill")
                                .foregroundColor(simulatorViewModel.isRunning ? .green : .red)
                            Text(simulatorViewModel.isRunning ? "Running" : "Stopped")
                                .foregroundColor(simulatorViewModel.isRunning ? .green : .red)
                        }
                        
                        Divider()
                        
                        // Speed Control
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Simulation Speed")
                                .font(.headline)
                            Picker("Simulation Speed", selection: .init(
                                get: { simulatorViewModel.speedMultiplier },
                                set: { simulatorViewModel.setSpeed($0) }
                            )) {
                                Text("1x").tag(1)
                                Text("5x").tag(5)
                                Text("10x").tag(10)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        
                        Divider()
                        
                        // Sales Boost Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sales Boost")
                                .font(.headline)
                            
                            if activeTriggers.isEmpty {
                                Text("No active triggers available")
                                    .foregroundColor(.gray)
                                    .italic()
                            } else {
                                Picker("Select Trigger", selection: $selectedTrigger) {
                                    Text("Select a trigger").tag(nil as PriceTrigger?)
                                    ForEach(activeTriggers) { trigger in
                                        Text(trigger.name ?? "Unknown")
                                            .tag(trigger as PriceTrigger?)
                                    }
                                }
                                .pickerStyle(.menu)
                                
                                if let selectedTrigger = selectedTrigger {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Selected Trigger Details:")
                                            .font(.subheadline)
                                        TriggerDetailView(trigger: selectedTrigger)
                                        
                                        Button(action: {
                                            toggleBoost()
                                        }) {
                                            HStack {
                                                Image(systemName: simulatorViewModel.isBoostActive ? "bolt.fill" : "bolt")
                                                Text(simulatorViewModel.isBoostActive ? "Stop Boost" : "Start Boost")
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(simulatorViewModel.isBoostActive ? Color.orange : Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Reset Button
                        Button(action: {
                            simulatorViewModel.resetSimulation()
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset Simulation")
                            }
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets())
                    .buttonStyle(BorderlessButtonStyle())
                }
                
                Section {
                    Button("Reset Database") {
                        showResetAlert = true
                    }
                    .foregroundColor(.orange)
                    
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
            }
        }
    }
    
    private func toggleBoost() {
        if simulatorViewModel.isBoostActive {
            simulatorViewModel.deactivateBoost()
        } else if let trigger = selectedTrigger {
            simulatorViewModel.activateBoost(trigger: trigger)
        }
    }
    
    private func resetProducts() {
        if simulatorViewModel.isRunning {
            simulatorViewModel.toggleSimulation()
        }
        
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

struct TriggerDetailView: View {
    let trigger: PriceTrigger
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if trigger.triggerType == "salesVolume" {
                Text("Type: Sales Volume")
                Text("Direction: \(trigger.direction?.capitalized ?? "N/A")")
                Text("Threshold: \(Int(trigger.percentageThreshold))%")
                Text("Time Window: \(trigger.timeWindow) hours")
            } else if trigger.triggerType == "timeBasedRule" {
                Text("Type: Time-Based")
                Text("Window: \(trigger.timeWindowStart):00 - \(trigger.timeWindowEnd):00")
                if let days = trigger.daysOfWeek {
                    Text("Days: \(days)")
                }
            }
            Text("Price Change: \(Int(trigger.priceChangePercentage))%")
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
}
