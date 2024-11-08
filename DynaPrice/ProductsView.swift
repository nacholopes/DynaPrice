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
    
    @State private var showingImportDialog = false
    @State private var showingFileImporter = false
    
    init(context: NSManagedObjectContext) {
        _importer = StateObject(wrappedValue: ProductImporter(context: context))
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(products, id: \.ean) { product in
                    VStack(alignment: .leading) {
                        Text(product.name ?? "Unknown")
                            .font(.headline)
                        Text(product.brand ?? "")
                            .font(.subheadline)
                        Text("R$ \(String(format: "%.2f", product.currentPrice))")
                            .font(.caption)
                            .foregroundColor(.blue)
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
                           allowedContentTypes: [.text],  // This accepts any text file
                           allowsMultipleSelection: false
                       ) { result in
                           switch result {
                           case .success(let files):
                               if let file = files.first {
                                   if file.startAccessingSecurityScopedResource() {
                                       do {
                                           let data = try String(contentsOf: file)
                                           importer.importProducts(from: data)
                                       } catch {
                                           print("Error reading file: \(error.localizedDescription)")
                                       }
                                       file.stopAccessingSecurityScopedResource()
                                   }
                               }
                           case .failure(let error):
                               print("Error selecting file: \(error.localizedDescription)")
                           }
                       }
                   }
               }
           }

#Preview {
    MonitoringView()
}
