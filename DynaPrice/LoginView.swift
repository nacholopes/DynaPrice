import SwiftUI

struct LoginView: View {
    @ObservedObject var authViewModel: AuthenticationViewModel
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 50)
                    
                    Text("DynaPrice")
                        .font(.largeTitle)
                        .bold()
                    
                    VStack(spacing: 15) {
                        TextField("Email", text: $authViewModel.email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .focused($focusedField, equals: .email)
                        
                        SecureField("Password", text: $authViewModel.password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($focusedField, equals: .password)
                        
                        Button(action: {
                            focusedField = nil
                            authViewModel.login()
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
                    
                    if authViewModel.showError {
                        Text(authViewModel.errorMessage)
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
        }
    }
}
