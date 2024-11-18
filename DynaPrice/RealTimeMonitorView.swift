import SwiftUI
import CoreData

struct RealTimeMonitorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var simulatorViewModel: POSSimulatorViewModel
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Sale.date, ascending: false)],
        animation: .default)
    private var recentSales: FetchedResults<Sale>
    
    // Track active suggestions
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PriceSuggestion.createdAt, ascending: false)],
        predicate: NSPredicate(format: "status == %@", "pending"),
        animation: .default)
    private var suggestions: FetchedResults<PriceSuggestion>
    
    init(viewContext: NSManagedObjectContext) {
        _simulatorViewModel = StateObject(wrappedValue: POSSimulatorViewModel(context: viewContext))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Simulation Status Bar
                simulationStatusBar
                
                // Main Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Active Suggestions Card
                        if !suggestions.isEmpty {
                            activeSuggestionsCard
                        }
                        
                        // Recent Activity Card
                        recentActivityCard
                        
                        // Live Metrics Card
                        liveMetricsCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Live Monitor")
        }
    }
    
    private var simulationStatusBar: some View {
            HStack(spacing: 16) {
                // Simulation Status
                Label(
                    simulatorViewModel.isRunning ? "Running" : "Stopped",
                    systemImage: simulatorViewModel.isRunning ? "circle.fill" : "circle"
                )
                .foregroundColor(simulatorViewModel.isRunning ? .green : .red)
                
                Divider()
                
                // Speed
                Label("\(simulatorViewModel.speedMultiplier)x", systemImage: "speedometer")
                
                Divider()
                
                // Time - Fixed formatting
                Label(
                    simulatorViewModel.simulationTime.formatted(date: .omitted, time: .shortened),
                    systemImage: "clock"
                )
                .font(.caption)
            }
            .padding(8)
            .background(Color(.systemGray6))
        }
    
    private var activeSuggestionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Price Suggestions")
                .font(.headline)
            
            ForEach(suggestions) { suggestion in
                suggestionRow(suggestion)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func suggestionRow(_ suggestion: PriceSuggestion) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(suggestion.product?.name ?? "Unknown Product")
                            .font(.subheadline)
                            .bold()
                        
                        // Add trigger name
                        if let triggerName = suggestion.trigger?.name {
                            Text("Trigger: \(triggerName)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        Text(suggestion.reason ?? "")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    priceChangeLabel(
                        current: suggestion.currentPrice,
                        suggested: suggestion.suggestedPrice
                    )
                }
                
                HStack {
                    Button("Accept") {
                        acceptSuggestion(suggestion)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Reject") {
                        rejectSuggestion(suggestion)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    
    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
            
            ForEach(recentSales.prefix(5)) { sale in
                HStack {
                    VStack(alignment: .leading) {
                        Text(getProductName(for: sale))
                            .font(.subheadline)
                        Text("\(sale.quantity) units at R$ \(sale.unitPrice, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Text(sale.date ?? Date(), style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var liveMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Metrics")
                .font(.headline)
            
            HStack {
                metricBox(
                    title: "Total Sales",
                    value: "\(simulatorViewModel.totalSalesGenerated)"
                )
                
                Divider()
                
                metricBox(
                    title: "Active Suggestions",
                    value: "\(suggestions.count)"
                )
                
                Divider()
                
                metricBox(
                    title: "Recent Sales",
                    value: "\(recentSales.prefix(100).count)"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func metricBox(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.title2)
                .bold()
        }
        .frame(maxWidth: .infinity)
    }
    
    private func priceChangeLabel(current: Double, suggested: Double) -> some View {
        let percentChange = ((suggested - current) / current) * 100
        return HStack {
            Image(systemName: percentChange >= 0 ? "arrow.up.right" : "arrow.down.right")
            Text("\(abs(percentChange), specifier: "%.1f")%")
        }
        .foregroundColor(percentChange >= 0 ? .green : .red)
        .font(.caption)
        .padding(4)
        .background(
            (percentChange >= 0 ? Color.green : Color.red)
                .opacity(0.1)
        )
        .cornerRadius(4)
    }
    
    private func getProductName(for sale: Sale) -> String {
        let request = NSFetchRequest<Product>(entityName: "Product")
        request.predicate = NSPredicate(format: "ean == %@", sale.ean ?? "")
        request.fetchLimit = 1
        
        do {
            let products = try viewContext.fetch(request)
            return products.first?.name ?? "Unknown Product"
        } catch {
            return "Unknown Product"
        }
    }
    
    private func acceptSuggestion(_ suggestion: PriceSuggestion) {
        suggestion.product?.currentPrice = suggestion.suggestedPrice
        suggestion.status = "accepted"
        try? viewContext.save()
    }
    
    private func rejectSuggestion(_ suggestion: PriceSuggestion) {
        suggestion.status = "rejected"
        try? viewContext.save()
    }
}
