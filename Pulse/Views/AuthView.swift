//
//  AuthView.swift
//  Pulse
//
//  Created by Camilo Montero on 2026-02-05.
//

import SwiftUI

struct AuthView: View {
    @StateObject private var vm = AuthViewModel()
    @State private var isLogin = true

    var body: some View {
        VStack(spacing: 20) {
            Text(isLogin ? "Login" : "Register")
                .font(.largeTitle)
                .bold()

            TextField("Email", text: $vm.email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $vm.password)
                .textFieldStyle(.roundedBorder)

            if let error = vm.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    isLogin ? await vm.signIn() : await vm.signUp()
                }
            } label: {
                if vm.isLoading {
                    ProgressView()
                } else {
                    Text(isLogin ? "Login" : "Create Account")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)

            Button(isLogin ? "No account? Register" : "Already have an account? Login") {
                isLogin.toggle()
            }
            .font(.footnote)
        }
        .padding()
    }
}


#Preview {
    AuthView()
}
