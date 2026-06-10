//
//  SavingsAccount.swift
//  WealthPath
//

import Foundation
import Observation
import SwiftData

// MARK: – Paycheck settings

struct PaycheckSettings: Codable {
    var allocations: [String: Double] = [:]

    func currentPeriodID() -> String {
        let cal = Calendar.current; let now = Date()
        let m = cal.component(.month, from: now)
        let y = cal.component(.year, from: now)
        return "\(y)-\(String(format: "%02d", m))"
    }

    func isCurrentPeriod(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
    }

    func expectedMonthlyContribution(for accountID: UUID, availableIncome: Double) -> Double {
        guard availableIncome > 0,
              let pct = allocations[accountID.uuidString], pct > 0 else { return 0 }
        return availableIncome * pct / 100.0
    }

    func expectedContribution(for accountID: UUID, availableIncome: Double) -> Double {
        expectedMonthlyContribution(for: accountID, availableIncome: availableIncome)
    }
}

// MARK: – Contribution

struct Contribution: Identifiable, Codable {
    var id: UUID = UUID()
    var amount: Double
    var date: Date
}

// MARK: – Savings account

struct SavingsAccount: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var startingBalance: Double
    var annualReturnRate: Double
    var contributions: [Contribution] = []
    var completedPeriods: Set<String> = []
    var createdDate: Date = Date()
    var balanceAdjustment: Double = 0

    var baseBalance: Double {
        let r = annualReturnRate / 12.0
        let cal = Calendar.current; let now = Date()
        let n0 = max(0, cal.dateComponents([.month], from: createdDate, to: now).month ?? 0)
        var bal = startingBalance * pow(1 + r, Double(n0))
        for c in contributions {
            let nc = max(0, cal.dateComponents([.month], from: c.date, to: now).month ?? 0)
            bal += c.amount * pow(1 + r, Double(nc))
        }
        return bal
    }

    var currentBalance: Double { baseBalance + balanceAdjustment }

    func currentPeriodTotal(settings: PaycheckSettings) -> Double {
        contributions.filter { settings.isCurrentPeriod($0.date) }.reduce(0) { $0 + $1.amount }
    }

    func isCurrentPeriodComplete(settings: PaycheckSettings) -> Bool {
        completedPeriods.contains(settings.currentPeriodID())
    }

    func projectedBalance(yearsFromNow: Double, settings: PaycheckSettings, availableIncome: Double) -> Double {
        let r = annualReturnRate / 12.0
        let n = yearsFromNow * 12.0
        let pmt = settings.expectedMonthlyContribution(for: id, availableIncome: availableIncome)
        let pv = currentBalance
        guard r > 0 else { return pv + pmt * n }
        return pv * pow(1 + r, n) + pmt * (pow(1 + r, n) - 1) / r
    }

    struct ProjectionPoint: Identifiable {
        let id = UUID()
        let year: Double
        let balance: Double
    }

    func projectionData(years: Int = 30, settings: PaycheckSettings, availableIncome: Double) -> [ProjectionPoint] {
        stride(from: 0.0, through: Double(years), by: Double(years) / 60.0).map {
            ProjectionPoint(year: $0, balance: projectedBalance(yearsFromNow: $0, settings: settings, availableIncome: availableIncome))
        }
    }
}

// MARK: – Store

@Observable
@MainActor
final class SavingsStore {
    private let modelContext: ModelContext
    private let uid: String
    private let sync: FirestoreSyncManager

    private(set) var accounts: [SavingsAccount] = []
    private(set) var paycheckSettings: PaycheckSettings = PaycheckSettings()
    var availableIncome: Double = 0

    var totalBalance: Double { accounts.reduce(0) { $0 + $1.currentBalance } }

    var totalAllocatedMonthly: Double {
        accounts.reduce(0) {
            $0 + paycheckSettings.expectedMonthlyContribution(for: $1.id, availableIncome: availableIncome)
        }
    }

    var currentStreak: Int {
        let activeIDs = accounts
            .filter { paycheckSettings.expectedContribution(for: $0.id, availableIncome: availableIncome) > 0 }
            .map { $0.id }
        guard !activeIDs.isEmpty else { return 0 }

        let cal = Calendar.current
        var streak = 0
        var checkDate = Date()

        // If the current month isn't fully complete yet, skip it — it's still in progress.
        // This prevents a mid-month state from wiping out an existing streak.
        let curMonth = cal.component(.month, from: checkDate)
        let curYear  = cal.component(.year,  from: checkDate)
        let curPID   = "\(curYear)-\(String(format: "%02d", curMonth))"
        let currentMonthDone = activeIDs.allSatisfy { id in
            accounts.first(where: { $0.id == id })?.completedPeriods.contains(curPID) ?? false
        }
        if !currentMonthDone {
            checkDate = cal.date(byAdding: .month, value: -1, to: checkDate) ?? checkDate
        }

        for _ in 0..<60 {
            let month = cal.component(.month, from: checkDate)
            let year  = cal.component(.year,  from: checkDate)
            let pid   = "\(year)-\(String(format: "%02d", month))"

            let allDone = activeIDs.allSatisfy { id in
                accounts.first(where: { $0.id == id })?.completedPeriods.contains(pid) ?? false
            }

            guard allDone else { break }
            streak += 1
            checkDate = cal.date(byAdding: .month, value: -1, to: checkDate) ?? checkDate
        }

        return streak
    }

    func expectedContribution(for accountID: UUID) -> Double {
        paycheckSettings.expectedContribution(for: accountID, availableIncome: availableIncome)
    }

    init(modelContext: ModelContext, uid: String, sync: FirestoreSyncManager) {
        self.modelContext = modelContext
        self.uid = uid
        self.sync = sync
        load()
        Task { @MainActor in
            for await _ in NotificationCenter.default.notifications(named: .wealthPathDataSynced) {
                self.load()
            }
        }
    }

    func add(_ account: SavingsAccount) {
        guard let user = fetchUser() else { return }
        let sd = makeSD(from: account)
        sd.user = user
        modelContext.insert(sd)
        for c in account.contributions {
            let sdc = SDContribution(id: c.id, amount: c.amount, date: c.date)
            sdc.savingsAccount = sd
            modelContext.insert(sdc)
        }
        persist()
        sync.pushSavingsAccount(sd, uid: uid)
        load()
    }

    func update(_ account: SavingsAccount) {
        guard let sd = fetchSD(id: account.id) else { return }
        sd.name = account.name
        sd.startingBalance = account.startingBalance
        sd.annualReturnRate = account.annualReturnRate
        sd.balanceAdjustment = account.balanceAdjustment
        sd.completedPeriods = account.completedPeriods
        persist()
        sync.pushSavingsAccount(sd, uid: uid)
        load()
    }

    func updatePaycheckSettings(_ settings: PaycheckSettings) {
        guard let user = fetchUser() else { return }
        if let existing = user.paycheckSettings {
            for a in existing.allocations { modelContext.delete(a) }
            modelContext.delete(existing)
        }
        let sd = SDPaycheckSettings()
        sd.user = user
        modelContext.insert(sd)
        for (accountIDStr, percentage) in settings.allocations {
            guard let accountID = UUID(uuidString: accountIDStr) else { continue }
            let alloc = SDAllocation(accountID: accountID, percentage: percentage)
            alloc.settings = sd
            modelContext.insert(alloc)
        }
        persist()
        sync.pushPaycheckSettings(sd, uid: uid)
        paycheckSettings = settings
    }

    func logContribution(to accountID: UUID, amount: Double) {
        guard let i = accounts.firstIndex(where: { $0.id == accountID }),
              let sd = fetchSD(id: accountID) else { return }
        let newContrib = SDContribution(amount: amount, date: Date())
        newContrib.savingsAccount = sd
        modelContext.insert(newContrib)

        let pid = paycheckSettings.currentPeriodID()
        let expected = paycheckSettings.expectedContribution(for: accountID, availableIncome: availableIncome)
        accounts[i].contributions.append(Contribution(id: newContrib.id, amount: amount, date: newContrib.date))
        if expected > 0, !accounts[i].completedPeriods.contains(pid),
           accounts[i].currentPeriodTotal(settings: paycheckSettings) >= expected {
            accounts[i].completedPeriods.insert(pid)
            sd.completedPeriods = accounts[i].completedPeriods
        }
        persist()
        sync.pushContribution(newContrib, accountID: accountID, uid: uid)
        sync.pushSavingsAccount(sd, uid: uid)
        load()
    }

    func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { accounts[$0] }
        for account in toDelete {
            if let sd = fetchSD(id: account.id) {
                sync.deleteSavingsAccount(id: account.id, uid: uid)
                modelContext.delete(sd)
            }
            paycheckSettings.allocations.removeValue(forKey: account.id.uuidString)
        }
        if !toDelete.isEmpty {
            updatePaycheckSettings(paycheckSettings)
        }
        persist()
        load()
    }

    func deleteContribution(id: UUID, from accountID: UUID) {
        guard let sd = fetchSD(id: accountID),
              let contrib = sd.contributions.first(where: { $0.id == id }) else { return }
        sync.deleteContribution(id: id, accountID: accountID, uid: uid)
        modelContext.delete(contrib)
        if let i = accounts.firstIndex(where: { $0.id == accountID }) {
            accounts[i].contributions.removeAll { $0.id == id }
            recheckCompletion(at: i)
            sd.completedPeriods = accounts[i].completedPeriods
        }
        persist()
        sync.pushSavingsAccount(sd, uid: uid)
        load()
    }

    func updateContribution(id: UUID, amount: Double, in accountID: UUID) {
        guard let sd = fetchSD(id: accountID),
              let contrib = sd.contributions.first(where: { $0.id == id }) else { return }
        contrib.amount = amount
        persist()
        sync.pushContribution(contrib, accountID: accountID, uid: uid)
        if let i = accounts.firstIndex(where: { $0.id == accountID }),
           let j = accounts[i].contributions.firstIndex(where: { $0.id == id }) {
            accounts[i].contributions[j].amount = amount
            recheckCompletion(at: i)
            sd.completedPeriods = accounts[i].completedPeriods
        }
        persist()
        sync.pushSavingsAccount(sd, uid: uid)
        load()
    }

    private func recheckCompletion(at i: Int) {
        let pid = paycheckSettings.currentPeriodID()
        let total = accounts[i].currentPeriodTotal(settings: paycheckSettings)
        let expected = paycheckSettings.expectedContribution(for: accounts[i].id, availableIncome: availableIncome)
        guard expected > 0 else { return }
        if accounts[i].completedPeriods.contains(pid) && total < expected {
            accounts[i].completedPeriods.remove(pid)
        } else if !accounts[i].completedPeriods.contains(pid) && total >= expected {
            accounts[i].completedPeriods.insert(pid)
        }
    }

    private func makeSD(from account: SavingsAccount) -> SDSavingsAccount {
        SDSavingsAccount(id: account.id, name: account.name, startingBalance: account.startingBalance,
                         annualReturnRate: account.annualReturnRate, createdDate: account.createdDate,
                         balanceAdjustment: account.balanceAdjustment, completedPeriods: account.completedPeriods)
    }

    private func fetchUser() -> SDUser? {
        let descriptor = FetchDescriptor<SDUser>(predicate: #Predicate { $0.firebaseUID == uid })
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchSD(id: UUID) -> SDSavingsAccount? {
        let descriptor = FetchDescriptor<SDSavingsAccount>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private func persist() { try? modelContext.save() }

    private func load() {
        guard let user = fetchUser() else { accounts = []; return }
        accounts = user.savingsAccounts.map { sd in
            SavingsAccount(
                id: sd.id, name: sd.name, startingBalance: sd.startingBalance,
                annualReturnRate: sd.annualReturnRate,
                contributions: sd.contributions.map { Contribution(id: $0.id, amount: $0.amount, date: $0.date) },
                completedPeriods: sd.completedPeriods, createdDate: sd.createdDate,
                balanceAdjustment: sd.balanceAdjustment
            )
        }
        if let sdSettings = user.paycheckSettings {
            var settings = PaycheckSettings()
            for alloc in sdSettings.allocations {
                settings.allocations[alloc.accountID.uuidString] = alloc.percentage
            }
            paycheckSettings = settings
        }
    }
}
