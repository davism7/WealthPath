//
//  SDUser.swift
//  WealthPath
//

import Foundation
import SwiftData

@Model
final class SDUser {
    @Attribute(.unique) var firebaseUID: String
    var email: String
    var fullName: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SDPaycheck.user)
    var paychecks: [SDPaycheck] = []

    @Relationship(deleteRule: .cascade, inverse: \SDBill.user)
    var bills: [SDBill] = []

    @Relationship(deleteRule: .cascade, inverse: \SDSavingsAccount.user)
    var savingsAccounts: [SDSavingsAccount] = []

    @Relationship(deleteRule: .cascade, inverse: \SDNote.user)
    var notes: [SDNote] = []

    @Relationship(deleteRule: .cascade, inverse: \SDPaycheckSettings.user)
    var paycheckSettings: SDPaycheckSettings?

    @Relationship(deleteRule: .cascade, inverse: \SDBillChecklist.user)
    var billChecklistEntries: [SDBillChecklist] = []

    init(firebaseUID: String, email: String, fullName: String = "", createdAt: Date = Date()) {
        self.firebaseUID = firebaseUID
        self.email = email
        self.fullName = fullName
        self.createdAt = createdAt
    }
}
