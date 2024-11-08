import SwiftUI

struct MonitoringView: View {
    @State private var selectedTimeWindow = "Hour"
    let timeWindows = ["Hour", "Day", "Week", "Month"]
    
    var body: some View {
        NavigationView {
            VStack {
                // Time window picker
                Picker("Time Window", selection: $selectedTimeWindow) {
                    ForEach(timeWindows, id: \.self) { window in
                        Text(window).tag(window)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Alert cards for price suggestions
                ScrollView {
                    VStack(spacing: 12) {
                        PriceSuggestionCard(
                            product: "Doritos Original",
                            currentPrice: "R$ 7.99",
                            suggestedPrice: "R$ 8.49",
                            reason: "Sales increased by 25% in last hour"
                        )
                        
                        PriceSuggestionCard(
                            product: "Coca Cola 2L",
                            currentPrice: "R$ 8.99",
                            suggestedPrice: "R$ 8.49",
                            reason: "Competitor price decreased"
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Price Monitor")
        }
    }
}

struct PriceSuggestionCard: View {
    let product: String
    let currentPrice: String
    let suggestedPrice: String
    let reason: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(product)
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Current: \(currentPrice)")
                    Text("Suggested: \(suggestedPrice)")
                        .foregroundColor(.blue)
                }
                Spacer()
                HStack {
                    Button("Accept") {
                        // TODO: Handle price update
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Reject") {
                        // TODO: Handle rejection
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Text(reason)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

#Preview {
    MonitoringView()
}
