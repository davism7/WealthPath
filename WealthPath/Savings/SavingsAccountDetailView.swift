//
//  SavingsAccountDetailView.swift
//  WealthPath
//
//  Created by Davis Morales on 6/1/26.
//

import SwiftUI
import Charts

struct SavingsAccountDetailView: View {
    let accountID: UUID
    let store: SavingsStore

    @State private var showLogContribution = false
    @State private var showEditGoal = false
    @State private var showContributionsSheet = false
    @State private var editingContribution: Contribution? = nil
    @State private var projectionYears: Int = 1
    @State private var showYearPicker = false

    private var account: SavingsAccount? {
        store.accounts.first { $0.id == accountID }
    }

    var body: some View {
        if let account {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        balanceHeader(account)
                        periodCard(account)
                        chartCard(account)
                        historyCard(account)
                    }
                    .padding(16)
                    .padding(.bottom, 16)
                }

                logContributionBar(account)
            }
            .navigationTitle(account.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { showEditGoal = true }
                        .font(.subheadline)
                }
            }
            .sheet(isPresented: $showLogContribution) {
                LogContributionSheet(accountID: account.id, store: store)
            }
            .sheet(isPresented: $showEditGoal) {
                EditAccountSheet(account: account, store: store)
            }
            .sheet(item: $editingContribution) { contribution in
                EditContributionSheet(contribution: contribution, accountID: accountID, store: store)
            }
        }
    }

    // MARK: – Log contribution bar

    private func logContributionBar(_ account: SavingsAccount) -> some View {
        Button { showLogContribution = true } label: {
            Text("Log Contribution")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Color.wealthGreen)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: – Balance header

    private func balanceHeader(_ account: SavingsAccount) -> some View {
        let settings = store.paycheckSettings
        let allocationPct = settings.allocations[account.id.uuidString] ?? 0
        let isComplete = account.isCurrentPeriodComplete(settings: settings)

        return VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("Current Balance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(account.currentBalance, format: .currency(code: "USD"))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
            }
            HStack(spacing: 20) {
                statPill(label: "Return", value: String(format: "%.1f%%", account.annualReturnRate * 100))
                Divider().frame(height: 28)
                statPill(label: "Allocation", value: allocationPct > 0
                    ? String(format: "%.0f%%", allocationPct) : "—")
                Divider().frame(height: 28)
                VStack(spacing: 2) {
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(isComplete ? .wealthGreen : .red.opacity(0.7))
                    Text("This month")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: – Period progress

    private func periodCard(_ account: SavingsAccount) -> some View {
        let settings = store.paycheckSettings
        let expected = store.expectedContribution(for: account.id)
        let currentTotal = account.currentPeriodTotal(settings: settings)
        let progress = expected > 0 ? min(currentTotal / expected, 1.0) : 0.0
        let remaining = max(0, expected - currentTotal)
        let isComplete = account.isCurrentPeriodComplete(settings: settings)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Contribution Goal")
                    .font(.headline)
                Spacer()
                if isComplete {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.wealthGreen)
                }
            }

            if expected > 0 {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(currentTotal, format: .currency(code: "USD"))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("of \(expected, format: .currency(code: "USD")) this month")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6).fill(Color(.systemFill)).frame(height: 10)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isComplete ? Color.wealthGreen : Color.wealthGreen.opacity(0.8))
                            .frame(width: max(0, geo.size.width * progress), height: 10)
                            .animation(.spring(duration: 0.4), value: progress)
                    }
                }
                .frame(height: 10)

                if !isComplete {
                    Text("\(remaining, format: .currency(code: "USD")) more to complete goal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Set allocation to track contributions toward a goal.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: – Growth chart

    private func chartCard(_ account: SavingsAccount) -> some View {
        let settings = store.paycheckSettings
        let income = store.availableIncome
        let monthlyContrib = settings.expectedMonthlyContribution(for: account.id, availableIncome: income)
        let data = account.projectionData(years: projectionYears, settings: settings, availableIncome: income)
        let projected = account.projectedBalance(yearsFromNow: Double(projectionYears), settings: settings, availableIncome: income)
        let stride = xAxisStride(projectionYears)
        let axisValues = Array(Swift.stride(from: stride, through: Double(projectionYears), by: stride))

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Projected Growth")
                    .font(.headline)
                Spacer()
                Button { showYearPicker = true } label: {
                    HStack(spacing: 3) {
                        Text("\(projectionYears) yr")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.wealthGreen)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundColor(.wealthGreen)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.wealthGreen.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showYearPicker) {
                    yearPickerSheet
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Est. \(projected, format: .currency(code: "USD")) in \(projectionYears) \(projectionYears == 1 ? "year" : "years")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if monthlyContrib > 0 {
                    Text("\(monthlyContrib, format: .currency(code: "USD")) / mo from available income")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                } else {
                    Text("Add paychecks and set allocation for contribution-based projection.")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }

            Chart {
                ForEach(data) { pt in
                    AreaMark(x: .value("Year", pt.year), y: .value("Balance", pt.balance))
                        .foregroundStyle(LinearGradient(
                            colors: [Color.wealthGreen.opacity(0.22), .clear],
                            startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)

                    LineMark(x: .value("Year", pt.year), y: .value("Balance", pt.balance))
                        .foregroundStyle(Color.wealthGreen)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                }
            }
            .chartXScale(domain: 0...Double(projectionYears))
            .chartXAxis {
                AxisMarks(values: axisValues) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let yr = value.as(Double.self) {
                            Text("\(Int(yr))yr").font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) { Text(shortCurrency(v)).font(.caption2) }
                    }
                }
            }
            .frame(height: 200)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func xAxisStride(_ years: Int) -> Double {
        switch years {
        case 1...5:   return 1
        case 6...15:  return 5
        case 16...50: return 10
        default:      return 25
        }
    }

    private var yearPickerSheet: some View {
        NavigationStack {
            Picker("Years", selection: $projectionYears) {
                ForEach(1...100, id: \.self) { yr in
                    Text("\(yr) \(yr == 1 ? "year" : "years")").tag(yr)
                }
            }
            .pickerStyle(.wheel)
            .navigationTitle("Projection Years")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showYearPicker = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(280)])
    }

    // MARK: – Contribution history

    private func historyCard(_ account: SavingsAccount) -> some View {
        let all = account.contributions.reversed().map { $0 }
        let recent = Array(all.prefix(3))

        return VStack(alignment: .leading, spacing: 12) {
            Text("Contribution History")
                .font(.headline)

            if all.isEmpty {
                Text("No contributions logged yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(recent) { c in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.amount, format: .currency(code: "USD"))
                                .font(.subheadline.weight(.semibold))
                            Text(c.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if store.paycheckSettings.isCurrentPeriod(c.date) {
                            Menu {
                                Button { editingContribution = c } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.white)
                                Button(role: .destructive) {
                                    store.deleteContribution(id: c.id, from: accountID)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            } label: {
                                Image(systemName: "ellipsis.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                    .padding(8)
                                    .contentShape(Rectangle())
                            }
                        }
                    }
                    if c.id != recent.last?.id { Divider() }
                }

                if all.count > 3 {
                    Divider()
                    Button {
                        showContributionsSheet = true
                    } label: {
                        Text("Show All (\(all.count))")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.wealthGreen)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showContributionsSheet) {
            AllContributionsSheet(accountID: accountID, store: store)
        }
    }

    private func shortCurrency(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "$%.1fM", v / 1_000_000) }
        if v >= 1_000 { return String(format: "$%.0fK", v / 1_000) }
        return String(format: "$%.0f", v)
    }
}

// MARK: – All contributions sheet

struct AllContributionsSheet: View {
    let accountID: UUID
    let store: SavingsStore
    @State private var editingContribution: Contribution? = nil
    @Environment(\.dismiss) private var dismiss

    private var account: SavingsAccount? {
        store.accounts.first { $0.id == accountID }
    }

    private var contributions: [Contribution] {
        account?.contributions.reversed().map { $0 } ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(contributions) { c in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.amount, format: .currency(code: "USD"))
                                .font(.subheadline.weight(.semibold))
                            Text(c.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if store.paycheckSettings.isCurrentPeriod(c.date) {
                            Button(role: .destructive) {
                                store.deleteContribution(id: c.id, from: accountID)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editingContribution = c
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.wealthGreen)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Contribution History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(item: $editingContribution) { contribution in
            EditContributionSheet(contribution: contribution, accountID: accountID, store: store)
        }
    }
}

// MARK: – Edit contribution sheet

struct EditContributionSheet: View {
    let contribution: Contribution
    let accountID: UUID
    let store: SavingsStore

    @State private var amountText: String
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    init(contribution: Contribution, accountID: UUID, store: SavingsStore) {
        self.contribution = contribution
        self.accountID = accountID
        self.store = store
        _amountText = State(initialValue: String(format: "%.2f", contribution.amount))
    }

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            Text("Edit Contribution")
                .font(.headline)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("$")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                TextField("0.00", text: $amountText)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .multilineTextAlignment(.leading)
                    .fixedSize()
                if focused {
                    Button { focused = false } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 24)

            Button {
                if let v = parsedAmount, v > 0 {
                    store.updateContribution(id: contribution.id, amount: v, in: accountID)
                    dismiss()
                }
            } label: {
                Text("Save")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background((parsedAmount ?? 0) > 0 ? Color.wealthGreen : Color(.systemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .animation(.easeInOut(duration: 0.15), value: (parsedAmount ?? 0) > 0)
            }
            .disabled((parsedAmount ?? 0) <= 0)
            .padding(.horizontal, 24)

            Spacer()
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: – Log contribution sheet

struct LogContributionSheet: View {
    let accountID: UUID
    let store: SavingsStore

    @State private var amountText = ""
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            Text("Log Contribution")
                .font(.headline)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("$")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                TextField("0.00", text: $amountText)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .multilineTextAlignment(.leading)
                    .fixedSize()
                if focused {
                    Button { focused = false } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 24)

            Button {
                if let v = parsedAmount, v > 0 {
                    store.logContribution(to: accountID, amount: v)
                    dismiss()
                }
            } label: {
                Text("Log")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background((parsedAmount ?? 0) > 0 ? Color.wealthGreen : Color(.systemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .animation(.easeInOut(duration: 0.15), value: (parsedAmount ?? 0) > 0)
            }
            .disabled((parsedAmount ?? 0) <= 0)
            .padding(.horizontal, 24)

            Spacer()
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: – Edit account sheet

struct EditAccountSheet: View {
    @State private var account: SavingsAccount
    let store: SavingsStore

    @State private var nameText: String
    @State private var returnRateText: String
    @State private var balanceText: String
    @Environment(\.dismiss) private var dismiss

    private enum Field { case name, returnRate, balance }
    @FocusState private var focused: Field?

    init(account: SavingsAccount, store: SavingsStore) {
        _account = State(initialValue: account)
        self.store = store
        _nameText = State(initialValue: account.name)
        _returnRateText = State(initialValue: String(format: "%.2f", account.annualReturnRate * 100))
        _balanceText = State(initialValue: String(format: "%.2f", account.currentBalance))
    }

    private var parsedRate: Double? { Double(returnRateText.replacingOccurrences(of: ",", with: ".")) }
    private var parsedBalance: Double? { Double(balanceText.replacingOccurrences(of: ",", with: ".")) }

    private var isValid: Bool {
        !nameText.trimmingCharacters(in: .whitespaces).isEmpty &&
        (parsedRate ?? -1) >= 0 &&
        (parsedBalance ?? -1) >= 0
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            Text("Edit Account")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            VStack(spacing: 0) {
                inputRow("Account Name", text: $nameText, keyboard: .default, field: .name)
                Divider().padding(.leading, 16)
                inputRow("Annual Rate (%)", text: $returnRateText, keyboard: .decimalPad, field: .returnRate)
                Divider().padding(.leading, 16)
                inputRow("Current Balance ($)", text: $balanceText, keyboard: .decimalPad, field: .balance)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Button { saveAccount() } label: {
                Text("Save")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isValid ? Color.wealthGreen : Color(.systemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .animation(.easeInOut(duration: 0.15), value: isValid)
            }
            .disabled(!isValid)
            .padding(.horizontal, 20)

            Spacer()
        }
        .presentationDetents([.height(355)])
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private func inputRow(_ label: String, text: Binding<String>, keyboard: UIKeyboardType, field: Field) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            TextField("", text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .focused($focused, equals: field)
                .frame(maxWidth: 160)
            if focused == field {
                Button { focused = nil } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func saveAccount() {
        guard !nameText.trimmingCharacters(in: .whitespaces).isEmpty,
              let rate = parsedRate, rate >= 0,
              let newBalance = parsedBalance, newBalance >= 0 else { return }
        account.name = nameText.trimmingCharacters(in: .whitespaces)
        account.annualReturnRate = rate / 100.0
        account.balanceAdjustment = newBalance - account.baseBalance
        store.update(account)
        dismiss()
    }
}
