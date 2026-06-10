//
//  HomeView.swift
//  WealthPath
//

import SwiftUI

private extension Int {
    var ordinal: String {
        let suffix: String
        switch self % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch self % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(self)\(suffix)"
    }
}

struct HomeView: View {
    let paycheckStore: PaycheckStore
    let billStore: BillStore
    let savingsStore: SavingsStore
    let availableIncome: Double

    @State private var showProfile = false

    private var totalActualContributionsThisMonth: Double {
        savingsStore.accounts.reduce(0) { $0 + $1.currentPeriodTotal(settings: savingsStore.paycheckSettings) }
    }

    private var remainingBalance: Double {
        max(0, availableIncome - totalActualContributionsThisMonth)
    }

    private var accountsNeedingContribution: [SavingsAccount] {
        savingsStore.accounts.filter { account in
            savingsStore.expectedContribution(for: account.id) > 0 &&
            !account.isCurrentPeriodComplete(settings: savingsStore.paycheckSettings)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    remainingBalanceCard

                    HStack(spacing: 16) {
                        totalSavingsCard
                        streakCard
                    }

                    if !accountsNeedingContribution.isEmpty {
                        needsContributionCard
                    } else if savingsStore.accounts.contains(where: { savingsStore.expectedContribution(for: $0.id) > 0 }) {
                        allContributionsSatisfiedCard
                    }

                    if billStore.bills.contains(where: { $0.paymentType == .manualPay }) {
                        billsChecklistCard
                    }
                }
                .padding(16)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        Image(systemName: "person.circle")
                            .font(.title3)
                    }
                    .tint(.wealthGreen)
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
        }
    }

    // MARK: – Remaining Balance Hero Card

    private var remainingBalanceCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Remaining Balance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(remainingBalance, format: .currency(code: "USD"))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                Text("after bills & contributions")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }

            HStack(spacing: 0) {
                statPill(label: "Income", value: paycheckStore.currentMonthTotal, color: .wealthGreen)
                Spacer()
                statPill(label: "Bills", value: billStore.totalMonthlyBills, color: Color(red: 0.95, green: 0.38, blue: 0.28))
                Spacer()
                statPill(label: "Savings", value: totalActualContributionsThisMonth, color: .wealthGreen.opacity(0.8))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func statPill(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value, format: .currency(code: "USD"))
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundColor(color)
        }
    }

    // MARK: – Mini Cards

    private var totalSavingsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "building.columns.fill")
                    .font(.caption)
                    .foregroundColor(.wealthGreen)
                Text("Total Savings")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(savingsStore.totalBalance, format: .currency(code: "USD"))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .padding(.bottom, 2)
            Text("\(savingsStore.accounts.count) account\(savingsStore.accounts.count == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("Streak")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(savingsStore.currentStreak)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .padding(.bottom, 2)
            Text(savingsStore.currentStreak == 1 ? "month" : "months")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: – All Contributions Satisfied Card

    private var allContributionsSatisfiedCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundColor(.wealthGreen)
            VStack(alignment: .leading, spacing: 3) {
                Text("All Contributions Met")
                    .font(.subheadline.weight(.semibold))
                Text("Great work — every account is funded this month.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.wealthGreen.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.wealthGreen.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: – Needs Contribution Card

    private var needsContributionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.red)
                Text("Needs Contribution")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(accountsNeedingContribution.count)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red)
                    .clipShape(Capsule())
            }

            ForEach(accountsNeedingContribution) { account in
                let expected = savingsStore.expectedContribution(for: account.id)
                let current = account.currentPeriodTotal(settings: savingsStore.paycheckSettings)
                let progress = expected > 0 ? min(current / expected, 1.0) : 0

                NavigationLink {
                    SavingsAccountDetailView(accountID: account.id, store: savingsStore)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(account.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            Text("\(current, format: .currency(code: "USD")) of \(expected, format: .currency(code: "USD"))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .stroke(Color.red.opacity(0.2), lineWidth: 3)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(Color.red, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 30, height: 30)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: – Bills Checklist Card

    private var billsChecklistCard: some View {
        let paidIDs = billStore.paidBillIDs()
        let manualBills = billStore.bills.filter { $0.paymentType == .manualPay }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Bills Checklist")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(paidIDs.count)/\(manualBills.count) paid")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            ForEach(manualBills.sorted { !paidIDs.contains($0.id) && paidIDs.contains($1.id) }) { bill in
                let isPaid = paidIDs.contains(bill.id)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        billStore.toggleBillPaid(bill.id)
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(isPaid ? Color.wealthGreen : Color.red.opacity(0.5), lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                            if isPaid {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.wealthGreen)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bill.name)
                                .font(.subheadline)
                                .foregroundColor(isPaid ? .secondary : .primary)
                                .strikethrough(isPaid, color: .secondary)
                            if let day = bill.dueDay {
                                Text("Due \(day.ordinal) of month")
                                    .font(.caption2)
                                    .foregroundColor(.secondary.opacity(isPaid ? 0.5 : 0.8))
                            }
                        }
                        Spacer()
                        Text(bill.monthlyAmount, format: .currency(code: "USD"))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundColor(isPaid ? .secondary : .red.opacity(0.8))
                    }
                    .padding(12)
                    .background(isPaid ? Color.wealthGreen.opacity(0.06) : Color.red.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
