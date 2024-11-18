import SwiftUI
import CoreData

struct MonitoringView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var salesAnalyzer: SalesAnalyzer
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Product.name, ascending: true)],
        animation: .default)
    private var products: FetchedResults<Product>
    
    @State private var selectedTimeWindow = "Hour"
    let timeWindows = ["Hour", "Day", "Week", "Month"]
    @State private var suggestions: [PriceSuggestion] = []
    @State private var debugInfo = ""
    
    init(viewContext: NSManagedObjectContext) {
        _salesAnalyzer = StateObject(wrappedValue: SalesAnalyzer(context: viewContext))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Debug info section
                VStack(alignment: .leading) {
                    Text("Debug Info:")
                        .font(.caption)
                    Text("Products loaded: \(products.count)")
                        .font(.caption)
                    Text("Active suggestions: \(suggestions.count)")
                        .font(.caption)
                    Text("Selected window: \(selectedTimeWindow)")
                        .font(.caption)
                    Text(debugInfo)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                
                Picker("Time Window", selection: $selectedTimeWindow) {
                    ForEach(timeWindows, id: \.self) { window in
                        Text(window).tag(window)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: selectedTimeWindow) { oldValue, newValue in
                    debugInfo = "Loading suggestions for \(newValue)"
                    loadSuggestions(for: newValue)
                }
                
                if suggestions.isEmpty {
                    VStack {
                        Text("No price change suggestions")
                            .foregroundColor(.gray)
                        Text("No sales data for selected period")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(suggestions, id: \.id) { suggestion in
                            if suggestion.status == "pending" &&
                               suggestion.productCurrentPrice == suggestion.product?.currentPrice {
                                PriceSuggestionCard(suggestion: suggestion,
                                    onAccept: {
                                        acceptSuggestion(suggestion)
                                    },
                                    onReject: {
                                        rejectSuggestion(suggestion)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Price Monitor")
            .onAppear {
                debugInfo = "View appeared"
                loadSuggestions(for: selectedTimeWindow)
            }
        }
    }
    
    private func loadSuggestions(for timeWindow: String) {
        let timeWindowHours: Int
        switch timeWindow {
        case "Hour":
            timeWindowHours = 1
        case "Day":
            timeWindowHours = 24
        case "Week":
            timeWindowHours = 24 * 7
        case "Month":
            timeWindowHours = 24 * 30
        default:
            timeWindowHours = 1
        }
        
        // First, load existing pending suggestions for this time window
        let fetchRequest: NSFetchRequest<PriceSuggestion> = PriceSuggestion.fetchRequest()
        let now = Date()
        let timeWindowStart = Calendar.current.date(byAdding: .hour, value: -timeWindowHours, to: now)!
        
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "status == %@", "pending"),
            NSPredicate(format: "productCurrentPrice == product.currentPrice"),
            NSPredicate(format: "timestamp >= %@", timeWindowStart as NSDate)
        ])
        
        do {
            suggestions = try viewContext.fetch(fetchRequest)
            
            // If no suggestions exist, analyze sales for this period
            if suggestions.isEmpty {
                for product in products {
                    if let suggestion = salesAnalyzer.analyzeSalesForProduct(product, timeWindow: selectedTimeWindow) {
                        suggestions.append(suggestion)
                    }
                }
                
                try viewContext.save()
            }
        } catch {
            print("Error loading suggestions: \(error)")
        }
    }
    
    private func acceptSuggestion(_ suggestion: PriceSuggestion) {
        viewContext.performAndWait {
            suggestion.product?.currentPrice = suggestion.suggestedPrice
            suggestion.status = "accepted"
            try? viewContext.save()
            suggestions.removeAll { $0.id == suggestion.id }
        }
    }
    
    private func rejectSuggestion(_ suggestion: PriceSuggestion) {
        viewContext.performAndWait {
            suggestion.status = "rejected"
            try? viewContext.save()
            suggestions.removeAll { $0.id == suggestion.id }
        }
    }
}

struct PriceSuggestionCard: View {
    let suggestion: PriceSuggestion
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(suggestion.product?.name ?? "Unknown")
                    .font(.headline)
                Text(suggestion.product?.brand ?? "")
                    .font(.headline)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text(String(format: "Current: R$ %.2f", suggestion.currentPrice))
                    Text(String(format: "Suggested: R$ %.2f", suggestion.suggestedPrice))
                        .foregroundColor(.blue)
                }
                Spacer()
                HStack {
                    Button("Accept", action: onAccept)
                        .buttonStyle(.borderedProminent)
                    
                    Button(action: onReject) {
                        Text("Reject")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Text(suggestion.reason ?? "")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}
