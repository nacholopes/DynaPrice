import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        LoginView(context: viewContext)
    }
}

#Preview {
    ContentView()
}
