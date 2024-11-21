import SwiftUI
import CoreData

struct RealTimeMonitorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var simulatorViewModel: POSSimulatorViewModel
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PriceSuggestion.createdAt, ascending: false)],
        predicate: NSPredicate(format: "status == %@", "pending"),
        animation: .default)
    private var suggestions: FetchedResults<PriceSuggestion>
    
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    
    init(viewContext: NSManagedObjectContext) {
        _simulatorViewModel = StateObject(wrappedValue: POSSimulatorViewModel(context: viewContext))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        recentSalesList
                        
                        if !suggestions.isEmpty {
                            priceSuggestionsCard
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Real-Time Monitor")
            //.navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    private var simulationStatusBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                SimulationStatusIndicator(isRunning: simulatorViewModel.isRunning)
                SimulationSpeedIndicator(speed: simulatorViewModel.speedMultiplier)
                SimulationTimeDisplay(time: simulatorViewModel.simulationTime)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .shadow(radius: 1)
    }
    
    private var recentSalesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cart.fill")
                Text("Recent Sales")
                    .font(.headline)
            }
            .padding(.bottom, 4)
            
            if simulatorViewModel.recentSales.isEmpty {
                Text("No sales recorded")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(simulatorViewModel.recentSales.prefix(10)) { sale in
                    SaleRow(sale: sale)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
    }
    
    private var priceSuggestionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Price Suggestions")
                    .font(.headline)
                Spacer()
                Button(action: rejectAllSuggestions) {
                    Text("Reject All")
                        .foregroundColor(.red)
                }
            }
            
            ForEach(suggestions) { suggestion in
                PriceSuggestionRow(
                    suggestion: suggestion,
                    onAccept: { acceptSuggestion(suggestion) },
                    onReject: { rejectSuggestion(suggestion) }
                )
                
                if suggestion.id != suggestions.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
    }
    
    private func acceptSuggestion(_ suggestion: PriceSuggestion) {
        viewContext.performAndWait {
            do {
                suggestion.product?.currentPrice = suggestion.suggestedPrice
                suggestion.status = "accepted"
                try viewContext.save()
            } catch {
                errorMessage = "Failed to accept suggestion: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }
    
    private func rejectSuggestion(_ suggestion: PriceSuggestion) {
        viewContext.performAndWait {
            do {
                suggestion.status = "rejected"
                try viewContext.save()
            } catch {
                errorMessage = "Failed to reject suggestion: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }
    
    private func rejectAllSuggestions() {
        viewContext.performAndWait {
            do {
                suggestions.forEach { $0.status = "rejected" }
                try viewContext.save()
            } catch {
                errorMessage = "Failed to reject suggestions: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }
}

// MARK: - Supporting Views
struct SimulationStatusIndicator: View {
    let isRunning: Bool
    
    var body: some View {
        Label(
            isRunning ? "Running" : "Stopped",
            systemImage: isRunning ? "circle.fill" : "circle"
        )
        .foregroundColor(isRunning ? .green : .red)
        .font(.subheadline)
    }
}

struct SimulationSpeedIndicator: View {
    let speed: Int
    
    var body: some View {
        Label(
            "\(speed)x",
            systemImage: "speedometer"
        )
        .font(.subheadline)
    }
}

struct SimulationTimeDisplay: View {
    let time: Date
    
    var body: some View {
        Label(
            time.formatted(date: .omitted, time: .shortened),
            systemImage: "clock"
        )
        .font(.subheadline)
    }
}

struct SaleRow: View {
    let sale: Sale
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sale.product?.name ?? "Unknown Product")
                    .font(.system(.body, design: .rounded))
                    .lineLimit(1)
                
                Text(sale.ean ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(sale.quantity) units")
                    .font(.subheadline)
                
                Text(String(format: "R$ %.2f", sale.totalAmount))
                    .font(.subheadline)
                    .bold()
            }
        }
        .padding(.vertical, 4)
    }
}

struct PriceSuggestionRow: View {
    let suggestion: PriceSuggestion
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(suggestion.product?.name ?? "Unknown")
                    .font(.system(.body, design: .rounded))
                    .bold()
                Spacer()
                priceChangeLabel
            }
            
            if let reason = suggestion.reason {
                Text(reason)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack {
                Button(action: onAccept) {
                    Label("Accept", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: onReject) {
                    Label("Reject", systemImage: "xmark")
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var priceChangeLabel: some View {
        let percentChange = ((suggestion.suggestedPrice - suggestion.currentPrice) / suggestion.currentPrice) * 100
        
        return HStack(spacing: 4) {
            Image(systemName: percentChange >= 0 ? "arrow.up.right" : "arrow.down.right")
            Text(String(format: "%.1f%%", abs(percentChange)))
        }
        .font(.caption.bold())
        .foregroundColor(percentChange >= 0 ? .green : .red)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            (percentChange >= 0 ? Color.green : Color.red)
                .opacity(0.1)
        )
        .cornerRadius(8)
    }
}
