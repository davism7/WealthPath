//
//  SavingsView.swift
//  WealthPath
//
//  Created by Davis Morales on 6/1/26.
//

import SwiftUI

struct SavingsView: View {
    let store: SavingsStore
    @State private var showAddAccount = false
    @State private var showSetPaycheck = false

    var body: some View {
        NavigationStack {
            Group {
                if store.accounts.isEmpty {
                    emptyStateView
                } else {
                    accountListView
                }
            }
            .navigationTitle("")
            .toolbar {
                if !store.accounts.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Set") { showSetPaycheck = true }
                            .font(.subheadline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddAccount = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showAddAccount) {
                AddSavingsAccountView(store: store)
            }
            .sheet(isPresented: $showSetPaycheck) {
                SetPaycheckView(store: store)
            }
        }
    }

    private var accountListView: some View {
        List {
            // Summary header
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("Total Balance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(store.totalBalance, format: .currency(code: "USD"))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                }
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                    Text("\(store.currentStreak) \(store.currentStreak == 1 ? "month" : "months")")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 6, trailing: 16))

            Text("Accounts")
                .font(.headline)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))

            ForEach(store.accounts) { account in
                NavigationLink {
                    SavingsAccountDetailView(accountID: account.id, store: store)
                } label: {
                    AccountCardView(
                        account: account,
                        settings: store.paycheckSettings,
                        expected: store.expectedContribution(for: account.id)
                    )
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onDelete { store.delete(at: $0) }
        }
        .listStyle(.plain)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "building.columns")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.secondary.opacity(0.4))
                .padding(.bottom, 6)

            Text("No Accounts Yet")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)

            Text("Tap + to add your first savings or investment account")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: – Account card

struct AccountCardView: View {
    let account: SavingsAccount
    let settings: PaycheckSettings
    let expected: Double

    private var currentTotal: Double { account.currentPeriodTotal(settings: settings) }
    private var progress: Double {
        guard expected > 0 else { return 0 }
        return min(currentTotal / expected, 1.0)
    }
    private var isComplete: Bool { account.isCurrentPeriodComplete(settings: settings) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(account.name)
                        .font(.headline)
                    Text("\(account.annualReturnRate * 100, specifier: "%.1f")% annual return")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(account.currentBalance, format: .currency(code: "USD"))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isComplete ? .wealthGreen : .red.opacity(0.7))
                }
            }

            if expected > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(isComplete
                             ? "Goal complete this month ✓"
                             : "Goal this month")
                            .font(.caption.weight(isComplete ? .semibold : .regular))
                            .foregroundColor(isComplete ? .wealthGreen : .secondary)
                        Spacer()
                        Text("\(currentTotal, format: .currency(code: "USD")) / \(expected, format: .currency(code: "USD"))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Color(.systemFill)).frame(height: 7)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isComplete ? Color.wealthGreen : Color.wealthGreen.opacity(0.75))
                                .frame(width: geo.size.width * progress, height: 7)
                        }
                    }
                    .frame(height: 7)
                }
            } else {
                Text("Set allocation to track contributions.")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: – Set allocation view

struct SetPaycheckView: View {
    let store: SavingsStore

    @State private var allocationTexts: [String: String]
    @Environment(\.dismiss) private var dismiss

    private enum Field: Hashable { case allocation(UUID) }
    @FocusState private var focused: Field?

    init(store: SavingsStore) {
        self.store = store
        let s = store.paycheckSettings
        var texts: [String: String] = [:]
        for account in store.accounts {
            if let pct = s.allocations[account.id.uuidString], pct > 0 {
                texts[account.id.uuidString] = String(format: "%.0f", pct)
            }
        }
        _allocationTexts = State(initialValue: texts)
    }

    private var availableIncome: Double { store.availableIncome }

    private func calculatedMonthlyAmount(for accountID: UUID) -> Double? {
        guard let pctStr = allocationTexts[accountID.uuidString],
              let pct = Double(pctStr), pct > 0,
              availableIncome > 0 else { return nil }
        return availableIncome * pct / 100.0
    }

    private var totalPercentage: Double {
        allocationTexts.values.compactMap { Double($0) }.reduce(0, +)
    }

    private var totalAllocated: Double {
        guard availableIncome > 0 else { return 0 }
        return availableIncome * min(totalPercentage, 100) / 100.0
    }

    private var incomeAfterContributions: Double {
        max(0, availableIncome - totalAllocated)
    }

    private var canSave: Bool {
        !store.accounts.isEmpty && totalPercentage > 0 && totalPercentage <= 100
    }

    private func percentageBinding(for accountID: UUID) -> Binding<String> {
        Binding(
            get: { allocationTexts[accountID.uuidString] ?? "" },
            set: { allocationTexts[accountID.uuidString] = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            HStack(alignment: .center) {
                Text("Set Allocation")
                    .font(.title3.weight(.semibold))
                Spacer()
                if totalPercentage > 0 {
                    Text("\(Int(totalPercentage))% allocated")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(totalPercentage > 100 ? .red : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background((totalPercentage > 100 ? Color.red : Color(.systemFill)).opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 12) {
                    // Income summary card
                    VStack(spacing: 0) {
                        HStack {
                            Text("Available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(availableIncome > 0
                                 ? availableIncome.formatted(.currency(code: "USD"))
                                 : "Add paychecks & bills")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(availableIncome > 0 ? .wealthGreen : .secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Divider().padding(.leading, 16)

                        HStack {
                            Text("Remaining")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(availableIncome > 0
                                 ? incomeAfterContributions.formatted(.currency(code: "USD"))
                                 : "—")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Allocations
                    if store.accounts.isEmpty {
                        Text("No accounts yet. Add accounts first")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Allocations")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            Divider().padding(.leading, 16)

                            ForEach(store.accounts) { account in
                                allocationRow(for: account)
                                if account.id != store.accounts.last?.id {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            Button { saveSettings() } label: {
                Text("Save")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSave ? Color.wealthGreen : Color(.systemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .animation(.easeInOut(duration: 0.15), value: canSave)
            }
            .disabled(!canSave)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private func allocationRow(for account: SavingsAccount) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.subheadline.weight(.medium))
                if let monthly = calculatedMonthlyAmount(for: account.id) {
                    Text("\(monthly, format: .currency(code: "USD")) / mo")
                        .font(.caption)
                        .foregroundColor(.wealthGreen)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            Spacer()
            TextField("0", text: percentageBinding(for: account.id))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 48)
                .focused($focused, equals: .allocation(account.id))
            Text("%")
                .foregroundColor(.secondary)
                .padding(.leading, 2)
            if focused == .allocation(account.id) {
                Button { focused = nil } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func saveSettings() {
        var newSettings = store.paycheckSettings
        newSettings.allocations = allocationTexts.compactMapValues { Double($0) }.filter { $0.value > 0 }
        store.updatePaycheckSettings(newSettings)
        dismiss()
    }
}
