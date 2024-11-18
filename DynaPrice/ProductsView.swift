import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ProductsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var importer: ProductImporter
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Product.name, ascending: true)],
        animation: .default)
    private var products: FetchedResults<Product>
    
    @State private var showingFileImporter = false
    @State private var debugInfo = ""
    
    init(viewContext: NSManagedObjectContext) {
        _importer = StateObject(wrappedValue: ProductImporter(context: viewContext))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if products.isEmpty {
                    Text("No products loaded")
                        .foregroundColor(.red)
                } else {
                    Text("Loaded \(products.count) products")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                List {
                    ForEach(products, id: \.ean) { product in
                        VStack(alignment: .leading, spacing: 4) {
                            // Name and brand in the same line
                            HStack {
                                Text(product.name ?? "Unknown")
                                    .font(.headline)
                                Text(product.brand ?? "")
                                    .font(.headline)
                            }
                            
                            // Description
                            if let description = product.productDescription, !description.isEmpty {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            // EAN and Price
                            HStack {
                                Text("EAN: \(product.ean ?? "N/A")")
                                    .font(.caption)
                                Spacer()
                                Text("R$ \(String(format: "%.2f", product.currentPrice))")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Products (\(products.count))")
            .toolbar {
                Button("Import CSV") {
                    showingFileImporter = true
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let files):
                    if let file = files.first {
                        if file.startAccessingSecurityScopedResource() {
                            do {
                                let data = try String(contentsOf: file)
                                importer.importProducts(from: data)
                                debugInfo = "Imported data: \(data.prefix(100))..."
                            } catch {
                                debugInfo = "Error reading file: \(error.localizedDescription)"
                                print(debugInfo)
                            }
                            file.stopAccessingSecurityScopedResource()
                        }
                    }
                case .failure(let error):
                    debugInfo = "Error selecting file: \(error.localizedDescription)"
                    print(debugInfo)
                }
            }
            .alert("Import Result", isPresented: $importer.showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importer.alertMessage)
            }
        }
    }
}
