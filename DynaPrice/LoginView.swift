import SwiftUI
import CoreData

struct LoginView: View {
    @StateObject private var viewModel: AuthenticationViewModel
    
    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: AuthenticationViewModel(context: context))
    }
    
    var body: some View {
        Group {
            if viewModel.isAuthenticated {
                MainTabView()
            } else {
                VStack(spacing: 20) {
                    Text("DynaPrice")
                        .font(.largeTitle)
                        .bold()
                    
                    VStack(spacing: 15) {
                        TextField("Email", text: $viewModel.email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                        
                        SecureField("Password", text: $viewModel.password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: {
                            print("Login button tapped")
                            viewModel.login()
                        }) {
                            Text("Login")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                    
                    if viewModel.showError {
                        Text(viewModel.errorMessage)
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
        }
    }
}

#Preview {
    MonitoringView()
}
