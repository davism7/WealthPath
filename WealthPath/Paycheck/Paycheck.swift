//
//  Paycheck.swift
//  WealthPath
//

import Foundation
import Observation
import SwiftData

struct Paycheck: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date
    var amount: Double
}

@Observable
@MainActor
final class PaycheckStore {
    private let modelContext: ModelContext
    private let uid: String
    private let sync: FirestoreSyncManager

    private(set) var paychecks: [Paycheck] = []

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

    var currentMonthTotal: Double {
        let cal = Calendar.current; let now = Date()
        return paychecks
            .filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    var expectedMonthlyIncome: Double {
        guard !paychecks.isEmpty else { return 0 }
        let cal = Calendar.current; let now = Date()
        var totals: [Double] = []
        for offset in 0..<3 {
            guard let ref = cal.date(byAdding: .month, value: -offset, to: now) else { continue }
            let total = paychecks
                .filter { cal.isDate($0.date, equalTo: ref, toGranularity: .month) }
                .reduce(0) { $0 + $1.amount }
            if total > 0 { totals.append(total) }
        }
        guard !totals.isEmpty else { return 0 }
        return totals.reduce(0, +) / Double(totals.count)
    }

    func add(_ paycheck: Paycheck) {
        guard let user = fetchUser() else { return }
        let sd = SDPaycheck(id: paycheck.id, date: paycheck.date, amount: paycheck.amount)
        sd.user = user
        modelContext.insert(sd)
        persist()
        sync.pushPaycheck(sd, uid: uid)
        load()
    }

    func update(_ paycheck: Paycheck) {
        guard let sd = fetchSD(id: paycheck.id) else { return }
        sd.date = paycheck.date
        sd.amount = paycheck.amount
        persist()
        sync.pushPaycheck(sd, uid: uid)
        load()
    }

    func delete(at offsets: IndexSet, in list: [Paycheck]) {
        let ids = offsets.map { list[$0].id }
        for id in ids {
            if let sd = fetchSD(id: id) {
                sync.deletePaycheck(id: id, uid: uid)
                modelContext.delete(sd)
            }
        }
        persist()
        load()
    }

    private func fetchUser() -> SDUser? {
        let descriptor = FetchDescriptor<SDUser>(predicate: #Predicate { $0.firebaseUID == uid })
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchSD(id: UUID) -> SDPaycheck? {
        let descriptor = FetchDescriptor<SDPaycheck>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private func persist() { try? modelContext.save() }

    private func load() {
        guard let user = fetchUser() else { paychecks = []; return }
        paychecks = user.paychecks
            .sorted { $0.date > $1.date }
            .map { Paycheck(id: $0.id, date: $0.date, amount: $0.amount) }
    }
}
