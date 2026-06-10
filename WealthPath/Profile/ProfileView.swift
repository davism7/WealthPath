//
//  ProfileView.swift
//  WealthPath
//

import SwiftUI
import SwiftData
import FirebaseAuth

struct ProfileView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext

    @State private var fullName = ""
    @State private var showEditName = false
    @State private var passwordResetSent = false
    @State private var showDeleteConfirm = false
    @State private var showDeleteAuth = false
    @State private var deleteError: String? = nil

    private var email: String { authManager.currentUser?.email ?? "" }

    private var initials: String {
        let parts = fullName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(fullName.prefix(2)).uppercased()
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.wealthGreen.opacity(0.12))
                                .frame(width: 60, height: 60)
                            Text(initials.isEmpty ? "?" : initials)
                                .font(.title2.weight(.semibold))
                                .foregroundColor(.wealthGreen)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(fullName.isEmpty ? "Your Name" : fullName)
                                .font(.headline)
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Account") {
                    Button { showEditName = true } label: {
                        HStack {
                            Label("Full Name", systemImage: "person")
                            Spacer()
                            Text(fullName.isEmpty ? "Not set" : fullName)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                    }
                    .foregroundColor(.primary)

                    Button {
                        Task {
                            try? await authManager.sendPasswordReset(email: email)
                            passwordResetSent = true
                        }
                    } label: {
                        Label("Change Password", systemImage: "lock")
                    }
                    .foregroundColor(.primary)
                }

                Section {
                    Button(role: .destructive) {
                        authManager.signOut()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Account")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .onAppear { loadProfile() }
            .presentationDragIndicator(.visible)
            .sheet(isPresented: $showEditName, onDismiss: { loadProfile() }) {
                EditNameSheet(initialName: fullName) { newName in
                    Task { await saveName(newName) }
                }
            }
            .alert("Password Reset Sent", isPresented: $passwordResetSent) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Check your email for a link to reset your password.")
            }
            .alert("Delete Account?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) { showDeleteAuth = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all your data. This cannot be undone.")
            }
            .sheet(isPresented: $showDeleteAuth) {
                DeleteAccountSheet { password in
                    Task { await performDeleteAccount(password: password) }
                }
            }
            .alert("Deletion Failed", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    private func performDeleteAccount(password: String) async {
        do {
            try await authManager.deleteAccount(password: password)
        } catch {
            deleteError = authManager.errorMessage ?? error.localizedDescription
        }
    }

    private func loadProfile() {
        guard let uid = authManager.currentUID else { return }
        let descriptor = FetchDescriptor<SDUser>(predicate: #Predicate { $0.firebaseUID == uid })
        if let user = try? modelContext.fetch(descriptor).first {
            fullName = user.fullName
        }
    }

    private func saveName(_ name: String) async {
        guard let uid = authManager.currentUID else { return }
        let descriptor = FetchDescriptor<SDUser>(predicate: #Predicate { $0.firebaseUID == uid })
        if let user = try? modelContext.fetch(descriptor).first {
            user.fullName = name
            try? modelContext.save()
        }
        fullName = name
        Task { try? await authManager.syncManager.updateUserProfile(uid: uid, fullName: name) }
    }
}

struct DeleteAccountSheet: View {
    let onDelete: (String) -> Void

    @State private var password = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Enter your password to confirm. All your data will be permanently removed.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Section {
                    SecureField("Password", text: $password)
                }
            }
            .navigationTitle("Confirm Deletion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Delete") {
                        onDelete(password)
                        dismiss()
                    }
                    .foregroundColor(.red)
                    .disabled(password.count < 6)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct EditNameSheet: View {
    let initialName: String
    let onSave: (String) -> Void

    @State private var name: String
    @Environment(\.dismiss) private var dismiss

    init(initialName: String, onSave: @escaping (String) -> Void) {
        self.initialName = initialName
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Full Name", text: $name)
                }
            }
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }
}
