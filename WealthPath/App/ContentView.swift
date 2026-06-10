//
//  ContentView.swift
//  WealthPath
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthenticationManager.self) private var authManager

    var body: some View {
        Group {
            if authManager.isLoading {
                SplashView()
                    .transition(.opacity)
            } else if authManager.isAuthenticated {
                MainTabView()
                    .transition(.opacity)
            } else {
                NavigationStack {
                    WelcomeView(onLogin: {})
                }
                .tint(.wealthGreen)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authManager.isLoading)
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { note in
            guard let field = note.object as? UITextField else { return }
            DispatchQueue.main.async {
                let end = field.endOfDocument
                field.selectedTextRange = field.textRange(from: end, to: end)
            }
        }
    }
}

#Preview {
    ContentView()
}
