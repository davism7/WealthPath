//
//  MainTabView.swift
//  WealthPath
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab = 0
    @State private var paycheckStore: PaycheckStore?
    @State private var billStore: BillStore?
    @State private var savingsStore: SavingsStore?
    @State private var notesStore: NotesStore?

    private var availableIncome: Double {
        guard let p = paycheckStore, let b = billStore else { return 0 }
        return max(0, p.currentMonthTotal - b.totalMonthlyBills)
    }

    var body: some View {
        Group {
            if let paycheckStore, let billStore, let savingsStore, let notesStore {
                TabView(selection: $selectedTab) {
                    HomeView(
                        paycheckStore: paycheckStore,
                        billStore: billStore,
                        savingsStore: savingsStore,
                        availableIncome: availableIncome
                    )
                    .tabItem { Label("Home", systemImage: "house") }
                    .tag(0)

                    PaycheckView(store: paycheckStore)
                        .tabItem { Label("Paychecks", systemImage: "dollarsign") }
                        .tag(1)

                    SavingsView(store: savingsStore)
                        .tabItem { Label("Savings", systemImage: "building.columns") }
                        .tag(2)

                    BillsView(store: billStore, monthlyIncome: paycheckStore.currentMonthTotal)
                        .tabItem { Label("Bills", systemImage: "list.bullet") }
                        .tag(3)

                    NotesView(store: notesStore)
                        .tabItem { Label("Notes", systemImage: "note.text") }
                        .tag(4)
                }
                .tint(.wealthGreen)
                .onChange(of: availableIncome) { _, newValue in
                    savingsStore.availableIncome = newValue
                }
                .onAppear {
                    savingsStore.availableIncome = availableIncome
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { initStores() }
    }

    private func initStores() {
        guard paycheckStore == nil, let uid = authManager.currentUID else { return }
        let sync = authManager.syncManager

        let paycheck = PaycheckStore(modelContext: modelContext, uid: uid, sync: sync)
        let bills    = BillStore(modelContext: modelContext, uid: uid, sync: sync)
        let savings  = SavingsStore(modelContext: modelContext, uid: uid, sync: sync)
        let notes    = NotesStore(modelContext: modelContext, uid: uid, sync: sync)

        savings.availableIncome = max(0, paycheck.currentMonthTotal - bills.totalMonthlyBills)

        MigrationManager.runIfNeeded(modelContext: modelContext, uid: uid)

        self.paycheckStore = paycheck
        self.billStore     = bills
        self.savingsStore  = savings
        self.notesStore    = notes
    }
}
