//
//  LoginView.swift
//  WealthPath
//

import SwiftUI

struct LoginView: View {
    var onLogin: () -> Void

    @Environment(AuthenticationManager.self) private var authManager
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome back")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Sign in to your account")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 36)

                VStack(spacing: 14) {
                    AuthTextField(
                        title: "Email",
                        text: $email,
                        icon: "at",
                        keyboardType: .emailAddress
                    )
                    AuthSecureField(title: "Password", text: $password)
                }

                if let error = authManager.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.subheadline)
                        Text(error)
                            .font(.subheadline)
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    Task {
                        isLoading = true
                        try? await authManager.signIn(email: email, password: password)
                        isLoading = false
                    }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Login")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(canSubmit ? Color.wealthGreen : Color(.systemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .animation(.easeInOut(duration: 0.15), value: canSubmit)
                }
                .disabled(!canSubmit || isLoading)

                NavigationLink(destination: CreateAccountView(onLogin: onLogin)) {
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .foregroundColor(.secondary)
                        Text("Create Account")
                            .foregroundColor(.wealthGreen)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { authManager.errorMessage = nil }
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && password.count >= 6
    }
}

#Preview {
    NavigationStack {
        LoginView(onLogin: {})
    }
    .tint(.wealthGreen)
}
