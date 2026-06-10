//
//  AuthComponents.swift
//  WealthPath
//
//  Created by Davis Morales on 6/1/26.
//

import SwiftUI

extension Color {
    static let wealthGreen = Color(red: 0.09, green: 0.38, blue: 0.24)
}

struct AuthTextField: View {
    let title: String
    @Binding var text: String
    var icon: String
    var keyboardType: UIKeyboardType = .default
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 22)
            TextField(title, text: $text)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isFocused)
            if isFocused {
                Button { isFocused = false } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AuthSecureField: View {
    let title: String
    @Binding var text: String
    @State private var isVisible = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .foregroundColor(.secondary)
                .frame(width: 22)
            Group {
                if isVisible {
                    TextField(title, text: $text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isFocused)
                } else {
                    SecureField(title, text: $text)
                        .focused($isFocused)
                }
            }
            if isFocused {
                Button { isFocused = false } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            Button(action: { isVisible.toggle() }) {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
