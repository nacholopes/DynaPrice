import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ProductsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var importer: ProductImporter
    @StateObject private var baselineImporter: BaselineImporter
    
   @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Product.name, ascending: true)],
        animation: .default)
    private var products: FetchedResults<Product>
    
    @State private var showingFileImporter = false
    @State private var showResetAlert = false
    @State private var showBaselineExplorer = false
    @State private var searchText = ""
    @State private var selectedProduct: Product?
    
    @State private var importType: ImportType = .products

    enum ImportType {
        case products
        case baselines
    }
    
    init(viewContext: NSManagedObjectContext) {
        _importer = StateObject(wrappedValue: ProductImporter(context: viewContext))
        _baselineImporter = StateObject(wrappedValue: BaselineImporter(context: viewContext))
    }
    
    var filteredProducts: [Product] {
        if searchText.isEmpty {
            return Array(products)
        }
        return products.filter { product in
            (product.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (product.ean?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                searchBar
                
                // Products List
                List {
                    ForEach(filteredProducts, id: \.ean) { product in
                        EnhancedProductRow(product: product)
                            .onTapGesture {
                                selectedProduct = product
                                showBaselineExplorer = true
                            }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Products (\(products.count))")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Import Products") {
                            importType = .products
                            showingFileImporter = true
                        }
                        Button("Import Baselines") {
                            importType = .baselines
                            showingFileImporter = true
                        }
//                        Button("Reset Database", role: .destructive) {
//                            showResetAlert = true
//                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showBaselineExplorer) {
                if let product = selectedProduct {
                    BaselineExplorerView(product: product)
                }
            }
            // Existing file importer and alerts remain unchanged
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search by name or EAN", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.horizontal)
    }
}

struct EnhancedProductRow: View {
    let product: Product
    @State private var currentBaseline: HourlyBaseline?
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product Info
            HStack {
                VStack(alignment: .leading) {
                    Text(product.name ?? "Unknown")
                        .font(.headline)
                    Text(product.brand ?? "")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
                PriceTag(price: product.currentPrice)
            }
            
            // EAN and Category
            HStack {
                Text("EAN: \(product.ean ?? "N/A")")
                    .font(.caption)
                Spacer()
                Text(product.category ?? "")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Current Baseline
            if let baseline = currentBaseline {
                BaselineSnapshotView(baseline: baseline)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            fetchCurrentBaseline()
        }
    }
    
    private func fetchCurrentBaseline() {
        guard let ean = product.ean else { return }
        
        let hourPeriod = Calendar.current.component(.hour, from: Date())
        let request = NSFetchRequest<HourlyBaseline>(entityName: "HourlyBaseline")
        request.predicate = NSPredicate(format: "ean == %@ AND hourPeriod == %d", ean, hourPeriod)
        request.fetchLimit = 1
        
        do {
            currentBaseline = try viewContext.fetch(request).first
        } catch {
            print("Error fetching baseline: \(error)")
        }
    }
}

struct BaselineSnapshotView: View {
    let baseline: HourlyBaseline
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Current Baseline")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                BaselineMetric(
                    label: "Avg Qty",
                    value: String(format: "%.1f", baseline.totalMeanQuantity)
                )
                Divider()
                BaselineMetric(
                    label: "Today Trend",
                    value: trendIndicator
                )
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var trendIndicator: String {
        let currentDayMean = (baseline.dailyMeans as? [Double])?[Calendar.current.component(.day, from: Date()) - 1] ?? 0
        let trend = ((currentDayMean - baseline.totalMeanQuantity) / baseline.totalMeanQuantity) * 100
        return String(format: "%+.1f%%", trend)
    }
}

struct BaselineMetric: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .bold()
        }
    }
}

struct PriceTag: View {
    let price: Double
    
    var body: some View {
        Text(String(format: "R$ %.2f", price))
            .font(.headline)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(6)
    }
}
