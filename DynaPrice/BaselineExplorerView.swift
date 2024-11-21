import SwiftUI
import CoreData

struct BaselineExplorerView: View {
    let product: Product
    @Environment(\.dismiss) private var dismiss
    @State private var selectedHourPeriod: Int = Calendar.current.component(.hour, from: Date())
    @State private var baseline: HourlyBaseline?
    @State private var selectedChart: ChartType = .hourly
    
    enum ChartType {
        case hourly, daily, monthly, weekday
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                productHeader
                timePeriodSelector
                
                Picker("Chart Type", selection: $selectedChart) {
                    Text("Hourly").tag(ChartType.hourly)
                    Text("Daily").tag(ChartType.daily)
                    Text("Monthly").tag(ChartType.monthly)
                    Text("Weekday").tag(ChartType.weekday)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                if let baseline = baseline {
                    BaselineDataView(baseline: baseline, chartType: selectedChart)
                } else {
                    Text("No baseline data available")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .navigationTitle("Baseline Explorer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            fetchBaseline()
        }
        .onChange(of: selectedHourPeriod) { oldValue, newValue in
            fetchBaseline()
        }
    }
    
    private var productHeader: some View {
        VStack(spacing: 8) {
            Text(product.name ?? "Unknown Product")
                .font(.headline)
            Text(product.ean ?? "")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var timePeriodSelector: some View {
        VStack(alignment: .leading) {
            Text("Hour Period")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("Hour Period", selection: $selectedHourPeriod) {
                ForEach(7...21, id: \.self) { hour in
                    Text(String(format: "%02d:00", hour)).tag(hour)
                }
            }
            .pickerStyle(.wheel)
        }
        .padding(.horizontal)
    }
    
    private func fetchBaseline() {
        guard let ean = product.ean else { return }
        let request = NSFetchRequest<HourlyBaseline>(entityName: "HourlyBaseline")
        request.predicate = NSPredicate(format: "ean == %@ AND hourPeriod == %d", ean, selectedHourPeriod)
        request.fetchLimit = 1
        
        baseline = try? PersistenceController.shared.container.viewContext.fetch(request).first
    }
}

struct BaselineDataView: View {
    let baseline: HourlyBaseline
    let chartType: BaselineExplorerView.ChartType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            summaryStats
            baselineChart
        }
        .padding()
    }
    
    private var summaryStats: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary Statistics")
                .font(.headline)
            
            HStack {
                StatBox(
                    label: "Mean",
                    value: String(format: "%.1f", baseline.totalMeanQuantity)
                )
                StatBox(
                    label: "Median",
                    value: String(format: "%.1f", baseline.totalMedianQuantity)
                )
            }
        }
    }
    
    private var baselineChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Distribution")
                .font(.headline)
            
            switch chartType {
            case .hourly:
                BaselineBarChart(data: hourlyData)
            case .daily:
                BaselineBarChart(data: dailyData)
            case .monthly:
                BaselineBarChart(data: monthlyData)
            case .weekday:
                BaselineBarChart(data: weekdayData)
            }
        }
    }
    
    private var hourlyData: [(String, Double)] {
        guard let means = baseline.monthlyMeans as? [Double] else { return [] }
        return means.enumerated().map { (i, value) in
            (String(format: "%02d:00", i + 7), value)
        }
    }
    
    private var dailyData: [(String, Double)] {
        guard let means = baseline.dailyMeans as? [Double] else { return [] }
        return means.enumerated().map { (i, value) in
            ("Day \(i + 1)", value)
        }
    }
    
    private var monthlyData: [(String, Double)] {
        guard let means = baseline.monthlyMeans as? [Double] else { return [] }
        return means.enumerated().map { (i, value) in
            (Calendar.current.monthSymbols[i], value)
        }
    }
    
    private var weekdayData: [(String, Double)] {
        guard let means = baseline.dowMeans as? [Double] else { return [] }
        return means.enumerated().map { (i, value) in
            (Calendar.current.weekdaySymbols[i], value)
        }
    }
}

struct StatBox: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct BaselineBarChart: View {
    let data: [(String, Double)]
    
    private var maxValue: Double {
        data.map { $0.1 }.max() ?? 1.0
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data.indices, id: \.self) { index in
                    VStack {
                        Rectangle()
                            .fill(Color.blue.opacity(0.7))
                            .frame(height: CGFloat(data[index].1 / maxValue) * 150)
                        
                        Text(data[index].0)
                            .font(.caption2)
                            .rotationEffect(.degrees(-45))
                            .frame(width: 40)
                    }
                }
            }
            .frame(height: 200)
            
            HStack {
                Text("0")
                Spacer()
                Text(String(format: "%.1f", maxValue))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}
