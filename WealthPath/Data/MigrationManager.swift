//
//  MigrationManager.swift
//  WealthPath
//

import Foundation
import SwiftData

final class MigrationManager {
    static let migrationKey = "wealthpath.migration.v2.complete"

    static func runIfNeeded(modelContext: ModelContext, uid: String) {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        let descriptor = FetchDescriptor<SDUser>(predicate: #Predicate { $0.firebaseUID == uid })
        guard let user = try? modelContext.fetch(descriptor).first else { return }

        migratePaychecks(user: user, context: modelContext)
        migrateBills(user: user, context: modelContext)
        migrateSavings(user: user, context: modelContext)
        migrateNotes(user: user, context: modelContext)
        migratePaycheckSettings(user: user, context: modelContext)

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: migrationKey)

        let legacyKeys = ["wealthpath.paychecks", "wealthpath.bills", "wealthpath.savings",
                          "wealthpath.savings.paycheck", "wealthpath.notes"]
        legacyKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    private static func migratePaychecks(user: SDUser, context: ModelContext) {
        guard let data = UserDefaults.standard.data(forKey: "wealthpath.paychecks"),
              let items = try? JSONDecoder().decode([LegacyPaycheck].self, from: data) else { return }
        for item in items {
            let sd = SDPaycheck(id: item.id, date: item.date, amount: item.amount)
            sd.user = user
            context.insert(sd)
        }
    }

    private static func migrateBills(user: SDUser, context: ModelContext) {
        guard let data = UserDefaults.standard.data(forKey: "wealthpath.bills"),
              let items = try? JSONDecoder().decode([LegacyBill].self, from: data) else { return }
        for item in items {
            let sd = SDBill(id: item.id, name: item.name, monthlyAmount: item.monthlyAmount,
                            dueDay: item.dueDay, paymentType: item.paymentType)
            sd.user = user
            context.insert(sd)
        }
    }

    private static func migrateSavings(user: SDUser, context: ModelContext) {
        guard let data = UserDefaults.standard.data(forKey: "wealthpath.savings"),
              let items = try? JSONDecoder().decode([LegacySavingsAccount].self, from: data) else { return }
        for item in items {
            let sd = SDSavingsAccount(
                id: item.id, name: item.name, startingBalance: item.startingBalance,
                annualReturnRate: item.annualReturnRate, createdDate: item.createdDate,
                balanceAdjustment: item.balanceAdjustment, completedPeriods: item.completedPeriods
            )
            sd.user = user
            context.insert(sd)
            for c in item.contributions {
                let sdc = SDContribution(id: c.id, amount: c.amount, date: c.date)
                sdc.savingsAccount = sd
                context.insert(sdc)
            }
        }
    }

    private static func migrateNotes(user: SDUser, context: ModelContext) {
        guard let data = UserDefaults.standard.data(forKey: "wealthpath.notes"),
              let items = try? JSONDecoder().decode([LegacyNote].self, from: data) else { return }
        for (index, item) in items.enumerated() {
            let sd = SDNote(id: item.id, title: item.title, content: item.content,
                            lastEdited: item.lastEdited, sortOrder: index)
            sd.user = user
            context.insert(sd)
        }
    }

    private static func migratePaycheckSettings(user: SDUser, context: ModelContext) {
        guard let data = UserDefaults.standard.data(forKey: "wealthpath.savings.paycheck"),
              let settings = try? JSONDecoder().decode(LegacyPaycheckSettings.self, from: data) else { return }
        let sd = SDPaycheckSettings()
        sd.user = user
        context.insert(sd)
        for (accountIDStr, percentage) in settings.allocations {
            guard let accountID = UUID(uuidString: accountIDStr) else { continue }
            let alloc = SDAllocation(accountID: accountID, percentage: percentage)
            alloc.settings = sd
            context.insert(alloc)
        }
    }
}

// MARK: - Legacy Decodable types matching old UserDefaults JSON

private struct LegacyPaycheck: Decodable {
    var id: UUID; var date: Date; var amount: Double
}

private struct LegacyBill: Decodable {
    var id: UUID; var name: String; var monthlyAmount: Double
    var dueDay: Int?; var paymentType: String
}

private struct LegacySavingsAccount: Decodable {
    var id: UUID; var name: String; var startingBalance: Double
    var annualReturnRate: Double; var contributions: [LegacyContribution]
    var completedPeriods: Set<String>; var createdDate: Date; var balanceAdjustment: Double
}

private struct LegacyContribution: Decodable {
    var id: UUID; var amount: Double; var date: Date
}

private struct LegacyNote: Decodable {
    var id: UUID; var title: String; var content: String; var lastEdited: Date
}

private struct LegacyPaycheckSettings: Decodable {
    var allocations: [String: Double]
}
