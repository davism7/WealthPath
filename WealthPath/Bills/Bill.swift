//
//  Bill.swift
//  WealthPath
//

import Foundation
import Observation
import SwiftData

enum PaymentType: String, Codable, CaseIterable {
    case autoPay, manualPay
}

struct Bill: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var monthlyAmount: Double
    var dueDay: Int?
    var paymentType: PaymentType = .manualPay
}

@Observable
@MainActor
final class BillStore {
    private let modelContext: ModelContext
    private let uid: String
    private let sync: FirestoreSyncManager

    private(set) var bills: [Bill] = []
    private(set) var billChecklistEntries: [SDBillChecklist] = []

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

    var totalMonthlyBills: Double { bills.reduce(0) { $0 + $1.monthlyAmount } }

    // MARK: - Bill CRUD

    func add(_ bill: Bill) {
        guard let user = fetchUser() else { return }
        let sd = SDBill(id: bill.id, name: bill.name, monthlyAmount: bill.monthlyAmount,
                        dueDay: bill.dueDay, paymentType: bill.paymentType.rawValue)
        sd.user = user
        modelContext.insert(sd)
        persist()
        sync.pushBill(sd, uid: uid)
        load()
    }

    func update(_ bill: Bill) {
        guard let sd = fetchSDBill(id: bill.id) else { return }
        sd.name = bill.name
        sd.monthlyAmount = bill.monthlyAmount
        sd.dueDay = bill.dueDay
        sd.paymentType = bill.paymentType.rawValue
        persist()
        sync.pushBill(sd, uid: uid)
        load()
    }

    func delete(at offsets: IndexSet) {
        let sorted = bills.sorted { $0.paymentType == .manualPay && $1.paymentType == .autoPay }
        let ids = offsets.map { sorted[$0].id }
        for id in ids {
            if let sd = fetchSDBill(id: id) {
                sync.deleteBill(id: id, uid: uid)
                modelContext.delete(sd)
            }
            // Delete all checklist entries for this bill
            for entry in billChecklistEntries.filter({ $0.billID == id }) {
                sync.deleteBillChecklistEntry(id: entry.id, uid: uid)
                modelContext.delete(entry)
            }
        }
        persist()
        load()
    }

    // MARK: - Bill Checklist

    func paidBillIDs() -> Set<UUID> {
        let key = currentMonthKey()
        return Set(billChecklistEntries.filter { $0.monthKey == key && $0.isPaid }.map { $0.billID })
    }

    func toggleBillPaid(_ billID: UUID) {
        let key = currentMonthKey()
        if let entry = billChecklistEntries.first(where: { $0.billID == billID && $0.monthKey == key }) {
            entry.isPaid.toggle()
            persist()
            sync.pushBillChecklistEntry(entry, uid: uid)
        } else {
            guard let user = fetchUser() else { return }
            let entry = SDBillChecklist(billID: billID, monthKey: key, isPaid: true)
            entry.user = user
            modelContext.insert(entry)
            persist()
            sync.pushBillChecklistEntry(entry, uid: uid)
        }
        loadChecklist()
    }

    // MARK: - Helpers

    private func currentMonthKey() -> String {
        let cal = Calendar.current; let now = Date()
        return "\(cal.component(.year, from: now))-\(String(format: "%02d", cal.component(.month, from: now)))"
    }

    private func fetchUser() -> SDUser? {
        let descriptor = FetchDescriptor<SDUser>(predicate: #Predicate { $0.firebaseUID == uid })
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchSDBill(id: UUID) -> SDBill? {
        let descriptor = FetchDescriptor<SDBill>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private func persist() { try? modelContext.save() }

    private func load() {
        guard let user = fetchUser() else { bills = []; return }
        bills = user.bills.map {
            Bill(id: $0.id, name: $0.name, monthlyAmount: $0.monthlyAmount,
                 dueDay: $0.dueDay, paymentType: PaymentType(rawValue: $0.paymentType) ?? .manualPay)
        }
        loadChecklist()
    }

    private func loadChecklist() {
        guard let user = fetchUser() else { billChecklistEntries = []; return }
        billChecklistEntries = user.billChecklistEntries
    }
}
