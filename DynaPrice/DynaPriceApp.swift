import SwiftUI

@main
struct DynaPriceApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        // Register the transformer
        DoubleArrayTransformer.register()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(context: persistenceController.container.viewContext)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
