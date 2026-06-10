//
//  AuthenticationManager.swift
//  WealthPath
//

import Foundation
import SwiftData
import FirebaseAuth
import Observation

@Observable
@MainActor
final class AuthenticationManager {
    var currentUser: FirebaseAuth.User? = nil
    var isLoading = true
    var errorMessage: String? = nil

    private let modelContext: ModelContext
    let syncManager: FirestoreSyncManager

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.syncManager = FirestoreSyncManager(modelContext: modelContext)
        setupAuthListener()
    }

    var isAuthenticated: Bool { currentUser != nil }
    var currentUID: String? { currentUser?.uid }

    private func setupAuthListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentUser = user
                self.isLoading = false
                if let uid = user?.uid {
                    await self.syncManager.pullUserData(uid: uid)
                }
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        errorMessage = nil
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            currentUser = result.user
            await syncManager.pullUserData(uid: result.user.uid)
        } catch {
            errorMessage = friendlyError(error)
            throw error
        }
    }

    func createAccount(email: String, fullName: String, password: String) async throws {
        errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid
            let user = SDUser(firebaseUID: uid, email: email, fullName: fullName)
            modelContext.insert(user)
            try modelContext.save()
            try await syncManager.createUserProfile(uid: uid, email: email, fullName: fullName)
            currentUser = result.user
        } catch {
            errorMessage = friendlyError(error)
            throw error
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func deleteAccount(password: String) async throws {
        guard let user = currentUser, let email = user.email else { return }
        errorMessage = nil
        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await user.reauthenticate(with: credential)
            guard let uid = currentUID else { return }
            try await syncManager.deleteAllUserData(uid: uid)
            deleteLocalData(uid: uid)
            try await user.delete()
            currentUser = nil
        } catch {
            errorMessage = friendlyError(error)
            throw error
        }
    }

    private func deleteLocalData(uid: String) {
        let descriptor = FetchDescriptor<SDUser>(predicate: #Predicate { $0.firebaseUID == uid })
        if let user = try? modelContext.fetch(descriptor).first {
            modelContext.delete(user)
            try? modelContext.save()
        }
    }

    private func friendlyError(_ error: Error) -> String {
        let code = AuthErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .wrongPassword, .invalidEmail, .userNotFound, .invalidCredential:
            return "Invalid email or password."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .networkError:
            return "Network error. Please try again."
        default:
            return error.localizedDescription
        }
    }
}
