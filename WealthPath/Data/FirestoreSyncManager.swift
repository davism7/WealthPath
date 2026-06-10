//
//  FirestoreSyncManager.swift
//  WealthPath
//

import Foundation
import SwiftData
import FirebaseFirestore

extension Notification.Name {
    static let wealthPathDataSynced = Notification.Name("WealthPathDataSynced")
}

@MainActor
final class FirestoreSyncManager {
    private let db = Firestore.firestore()
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - User Profile

    func updateUserProfile(uid: String, fullName: String) async throws {
        try await db.collection("users").document(uid).updateData(["fullName": fullName])
    }

    func deleteAllUserData(uid: String) async throws {
        let userRef = db.collection("users").document(uid)
        for collection in ["paychecks", "bills", "notes", "billChecklist", "paycheckSettings"] {
            let snap = try await userRef.collection(collection).getDocuments()
            for doc in snap.documents { try await doc.reference.delete() }
        }
        let savingsSnap = try await userRef.collection("savingsAccounts").getDocuments()
        for doc in savingsSnap.documents {
            let contribSnap = try await doc.reference.collection("contributions").getDocuments()
            for cDoc in contribSnap.documents { try await cDoc.reference.delete() }
            try await doc.reference.delete()
        }
        try await userRef.delete()
    }

    func createUserProfile(uid: String, email: String, fullName: String) async throws {
        try await db.collection("users").document(uid).setData([
            "email": email,
            "fullName": fullName,
            "createdAt": Timestamp(date: Date())
        ])
    }

    // MARK: - Pull (Firestore → SwiftData)

    func pullUserData(uid: String) async {
        do {
            let user = try ensureLocalUser(uid: uid)

            if let doc = try? await db.collection("users").document(uid).getDocument(),
               doc.exists, let data = doc.data() {
                if let v = data["email"] as? String, !v.isEmpty { user.email = v }
                if let v = data["fullName"] as? String, !v.isEmpty { user.fullName = v }
            }

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await self.pullPaychecks(user: user, uid: uid) }
                group.addTask { try await self.pullBills(user: user, uid: uid) }
                group.addTask { try await self.pullSavingsAccounts(user: user, uid: uid) }
                group.addTask { try await self.pullNotes(user: user, uid: uid) }
                group.addTask { try await self.pullPaycheckSettings(user: user, uid: uid) }
                group.addTask { try await self.pullBillChecklist(user: user, uid: uid) }
                try await group.waitForAll()
            }

            try modelContext.save()
            NotificationCenter.default.post(name: .wealthPathDataSynced, object: nil)
        } catch {
            print("[FirestoreSync] pullUserData error: \(error.localizedDescription)")
        }
    }

    private func ensureLocalUser(uid: String) throws -> SDUser {
        let descriptor = FetchDescriptor<SDUser>(predicate: #Predicate { $0.firebaseUID == uid })
        if let existing = try modelContext.fetch(descriptor).first { return existing }
        let user = SDUser(firebaseUID: uid, email: "", fullName: "")
        modelContext.insert(user)
        return user
    }

    private func pullPaychecks(user: SDUser, uid: String) async throws {
        let snapshot = try await db.collection("users/\(uid)/paychecks").getDocuments()
        let remoteIDs = Set(snapshot.documents.map { $0.documentID })
        for p in user.paychecks where !remoteIDs.contains(p.id.uuidString) { modelContext.delete(p) }
        let existingIDs = Set(user.paychecks.map { $0.id.uuidString })
        for doc in snapshot.documents where !existingIDs.contains(doc.documentID) {
            let data = doc.data()
            let p = SDPaycheck(
                id: UUID(uuidString: doc.documentID) ?? UUID(),
                date: (data["date"] as? Timestamp)?.dateValue() ?? Date(),
                amount: data["amount"] as? Double ?? 0
            )
            p.user = user
            modelContext.insert(p)
        }
    }

    private func pullBills(user: SDUser, uid: String) async throws {
        let snapshot = try await db.collection("users/\(uid)/bills").getDocuments()
        let remoteIDs = Set(snapshot.documents.map { $0.documentID })
        for b in user.bills where !remoteIDs.contains(b.id.uuidString) { modelContext.delete(b) }
        let existingIDs = Set(user.bills.map { $0.id.uuidString })
        for doc in snapshot.documents where !existingIDs.contains(doc.documentID) {
            let data = doc.data()
            let b = SDBill(
                id: UUID(uuidString: doc.documentID) ?? UUID(),
                name: data["name"] as? String ?? "",
                monthlyAmount: data["monthlyAmount"] as? Double ?? 0,
                dueDay: data["dueDay"] as? Int,
                paymentType: data["paymentType"] as? String ?? "manualPay"
            )
            b.user = user
            modelContext.insert(b)
        }
    }

    private func pullSavingsAccounts(user: SDUser, uid: String) async throws {
        let snapshot = try await db.collection("users/\(uid)/savingsAccounts").getDocuments()
        let remoteIDs = Set(snapshot.documents.map { $0.documentID })
        for a in user.savingsAccounts where !remoteIDs.contains(a.id.uuidString) { modelContext.delete(a) }
        let existingIDs = Set(user.savingsAccounts.map { $0.id.uuidString })
        for doc in snapshot.documents where !existingIDs.contains(doc.documentID) {
            let data = doc.data()
            let account = SDSavingsAccount(
                id: UUID(uuidString: doc.documentID) ?? UUID(),
                name: data["name"] as? String ?? "",
                startingBalance: data["startingBalance"] as? Double ?? 0,
                annualReturnRate: data["annualReturnRate"] as? Double ?? 0,
                createdDate: (data["createdDate"] as? Timestamp)?.dateValue() ?? Date(),
                balanceAdjustment: data["balanceAdjustment"] as? Double ?? 0,
                completedPeriods: Set(data["completedPeriods"] as? [String] ?? [])
            )
            account.user = user
            modelContext.insert(account)
            let contribSnap = try await db
                .collection("users/\(uid)/savingsAccounts/\(doc.documentID)/contributions")
                .getDocuments()
            for cDoc in contribSnap.documents {
                let cData = cDoc.data()
                let c = SDContribution(
                    id: UUID(uuidString: cDoc.documentID) ?? UUID(),
                    amount: cData["amount"] as? Double ?? 0,
                    date: (cData["date"] as? Timestamp)?.dateValue() ?? Date()
                )
                c.savingsAccount = account
                modelContext.insert(c)
            }
        }
    }

    private func pullNotes(user: SDUser, uid: String) async throws {
        let snapshot = try await db.collection("users/\(uid)/notes").getDocuments()
        let remoteIDs = Set(snapshot.documents.map { $0.documentID })
        for n in user.notes where !remoteIDs.contains(n.id.uuidString) { modelContext.delete(n) }
        let existingIDs = Set(user.notes.map { $0.id.uuidString })
        for doc in snapshot.documents where !existingIDs.contains(doc.documentID) {
            let data = doc.data()
            let note = SDNote(
                id: UUID(uuidString: doc.documentID) ?? UUID(),
                title: data["title"] as? String ?? "",
                content: data["content"] as? String ?? "",
                lastEdited: (data["lastEdited"] as? Timestamp)?.dateValue() ?? Date(),
                sortOrder: data["sortOrder"] as? Int ?? 0
            )
            note.user = user
            modelContext.insert(note)
        }
    }

    private func pullPaycheckSettings(user: SDUser, uid: String) async throws {
        let doc = try await db.collection("users/\(uid)/paycheckSettings").document("settings").getDocument()
        guard doc.exists, let data = doc.data() else { return }
        if let existing = user.paycheckSettings {
            for a in existing.allocations { modelContext.delete(a) }
            modelContext.delete(existing)
        }
        let settings = SDPaycheckSettings()
        settings.user = user
        modelContext.insert(settings)
        for aData in (data["allocations"] as? [[String: Any]] ?? []) {
            guard let idStr = aData["accountID"] as? String,
                  let accountID = UUID(uuidString: idStr),
                  let pct = aData["percentage"] as? Double else { continue }
            let alloc = SDAllocation(accountID: accountID, percentage: pct)
            alloc.settings = settings
            modelContext.insert(alloc)
        }
    }

    private func pullBillChecklist(user: SDUser, uid: String) async throws {
        let snapshot = try await db.collection("users/\(uid)/billChecklist").getDocuments()
        let remoteIDs = Set(snapshot.documents.map { $0.documentID })
        for e in user.billChecklistEntries where !remoteIDs.contains(e.id.uuidString) { modelContext.delete(e) }
        let existingIDs = Set(user.billChecklistEntries.map { $0.id.uuidString })
        for doc in snapshot.documents where !existingIDs.contains(doc.documentID) {
            let data = doc.data()
            guard let billIDStr = data["billID"] as? String,
                  let billID = UUID(uuidString: billIDStr),
                  let monthKey = data["monthKey"] as? String else { continue }
            let entry = SDBillChecklist(
                id: UUID(uuidString: doc.documentID) ?? UUID(),
                billID: billID, monthKey: monthKey,
                isPaid: data["isPaid"] as? Bool ?? false
            )
            entry.user = user
            modelContext.insert(entry)
        }
    }

    // MARK: - Push (SwiftData → Firestore)

    func pushPaycheck(_ p: SDPaycheck, uid: String) {
        Task { try? await db.collection("users/\(uid)/paychecks").document(p.id.uuidString)
            .setData(["date": Timestamp(date: p.date), "amount": p.amount]) }
    }

    func deletePaycheck(id: UUID, uid: String) {
        Task { try? await db.collection("users/\(uid)/paychecks").document(id.uuidString).delete() }
    }

    func pushBill(_ b: SDBill, uid: String) {
        Task {
            var data: [String: Any] = ["name": b.name, "monthlyAmount": b.monthlyAmount, "paymentType": b.paymentType]
            if let day = b.dueDay { data["dueDay"] = day }
            try? await db.collection("users/\(uid)/bills").document(b.id.uuidString).setData(data)
        }
    }

    func deleteBill(id: UUID, uid: String) {
        Task { try? await db.collection("users/\(uid)/bills").document(id.uuidString).delete() }
    }

    func pushSavingsAccount(_ a: SDSavingsAccount, uid: String) {
        Task {
            try? await db.collection("users/\(uid)/savingsAccounts").document(a.id.uuidString).setData([
                "name": a.name, "startingBalance": a.startingBalance,
                "annualReturnRate": a.annualReturnRate,
                "createdDate": Timestamp(date: a.createdDate),
                "balanceAdjustment": a.balanceAdjustment,
                "completedPeriods": Array(a.completedPeriods)
            ])
        }
    }

    func deleteSavingsAccount(id: UUID, uid: String) {
        Task {
            let accountRef = db.collection("users/\(uid)/savingsAccounts").document(id.uuidString)
            let contribSnap = try? await accountRef.collection("contributions").getDocuments()
            for doc in contribSnap?.documents ?? [] {
                try? await doc.reference.delete()
            }
            try? await accountRef.delete()
        }
    }

    func pushContribution(_ c: SDContribution, accountID: UUID, uid: String) {
        Task {
            try? await db
                .collection("users/\(uid)/savingsAccounts/\(accountID.uuidString)/contributions")
                .document(c.id.uuidString)
                .setData(["amount": c.amount, "date": Timestamp(date: c.date)])
        }
    }

    func deleteContribution(id: UUID, accountID: UUID, uid: String) {
        Task {
            try? await db
                .collection("users/\(uid)/savingsAccounts/\(accountID.uuidString)/contributions")
                .document(id.uuidString).delete()
        }
    }

    func pushNote(_ n: SDNote, uid: String) {
        Task {
            try? await db.collection("users/\(uid)/notes").document(n.id.uuidString).setData([
                "title": n.title, "content": n.content,
                "lastEdited": Timestamp(date: n.lastEdited), "sortOrder": n.sortOrder
            ])
        }
    }

    func deleteNote(id: UUID, uid: String) {
        Task { try? await db.collection("users/\(uid)/notes").document(id.uuidString).delete() }
    }

    func pushPaycheckSettings(_ s: SDPaycheckSettings, uid: String) {
        Task {
            let allocations = s.allocations.map { ["accountID": $0.accountID.uuidString, "percentage": $0.percentage] as [String: Any] }
            try? await db.collection("users/\(uid)/paycheckSettings").document("settings")
                .setData(["allocations": allocations])
        }
    }

    func pushBillChecklistEntry(_ e: SDBillChecklist, uid: String) {
        Task {
            try? await db.collection("users/\(uid)/billChecklist").document(e.id.uuidString).setData([
                "billID": e.billID.uuidString, "monthKey": e.monthKey, "isPaid": e.isPaid
            ])
        }
    }

    func deleteBillChecklistEntry(id: UUID, uid: String) {
        Task { try? await db.collection("users/\(uid)/billChecklist").document(id.uuidString).delete() }
    }
}
