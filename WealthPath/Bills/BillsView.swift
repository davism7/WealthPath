//
//  BillsView.swift
//  WealthPath
//
//  Created by Davis Morales on 6/1/26.
//

import SwiftUI

struct BillsView: View {
    let store: BillStore
    let monthlyIncome: Double
    @State private var showAddSheet = false
    @State private var editingBill: Bill? = nil

    private var incomePercentage: Double {
        guard monthlyIncome > 0 else { return 0 }
        return store.totalMonthlyBills / monthlyIncome * 100
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.bills.isEmpty {
                    emptyStateView
                } else {
                    billList
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddBillSheet(store: store)
        }
        .sheet(item: $editingBill) { bill in
            EditBillSheet(bill: bill, store: store)
        }
    }

    private var billList: some View {
        List {
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("Monthly Bills")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(store.totalMonthlyBills, format: .currency(code: "USD"))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                }
                HStack(spacing: 5) {
                    Image(systemName: "chart.pie.fill")
                        .font(.caption)
                    Text(monthlyIncome > 0
                         ? "\(Int(incomePercentage))% of income"
                         : "No income logged")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(incomePercentage > 50 ? Color(red: 0.95, green: 0.38, blue: 0.28) : .wealthGreen)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background((incomePercentage > 50 ? Color(red: 0.95, green: 0.38, blue: 0.28) : Color.wealthGreen).opacity(0.1))
                .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 6, trailing: 16))

            Text("Bills")
                .font(.headline)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))

            ForEach(store.bills.sorted { $0.paymentType == .manualPay && $1.paymentType == .autoPay }) { bill in
                BillRow(bill: bill)
                    .contentShape(Rectangle())
                    .onTapGesture { editingBill = bill }
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
            Image(systemName: "doc.plaintext")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.secondary.opacity(0.4))
                .padding(.bottom, 6)
            Text("No Bills Yet")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
            Text("Tap + to add your first recurring bill")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BillRow: View {
    let bill: Bill

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(bill.name)
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(bill.paymentType == .autoPay ? "Auto-Pay" : "Manual Pay")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(bill.paymentType == .autoPay ? .wealthGreen : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background((bill.paymentType == .autoPay ? Color.wealthGreen : Color(.systemFill)).opacity(0.15))
                        .clipShape(Capsule())
                    if let day = bill.dueDay {
                        Text("Due \(ordinal(day))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            Text(bill.monthlyAmount, format: .currency(code: "USD"))
                .font(.system(.subheadline, design: .rounded, weight: .bold))
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Add Sheet

struct AddBillSheet: View {
    let store: BillStore
    @State private var name = ""
    @State private var amountText = ""
    @State private var dueDayText = ""
    @State private var paymentType: PaymentType = .manualPay
    @Environment(\.dismiss) private var dismiss

    private enum Field: Hashable { case name, amount, dueDay }
    @FocusState private var focused: Field?

    private var parsedAmount: Double? { Double(amountText.replacingOccurrences(of: ",", with: ".")) }
    private var parsedDueDay: Int? {
        guard let d = Int(dueDayText), d >= 1, d <= 31 else { return nil }
        return d
    }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (parsedAmount ?? 0) > 0 &&
        (paymentType == .autoPay || parsedDueDay != nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            HStack {
                Text("Add Bill")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Save") {
                    guard let amount = parsedAmount,
                          !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    store.add(Bill(
                        name: name.trimmingCharacters(in: .whitespaces),
                        monthlyAmount: amount,
                        dueDay: paymentType == .manualPay ? parsedDueDay : nil,
                        paymentType: paymentType
                    ))
                    dismiss()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(canSave ? .wealthGreen : .secondary)
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            VStack(spacing: 0) {
                // Payment type picker
                HStack {
                    Text("Payment")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: $paymentType) {
                        Text("Auto-Pay").tag(PaymentType.autoPay)
                        Text("Manual Pay").tag(PaymentType.manualPay)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().padding(.leading, 16)

                sheetRow("Bill Name", field: .name) {
                    TextField("e.g. Rent", text: $name)
                        .font(.subheadline)
                        .multilineTextAlignment(.trailing)
                        .focused($focused, equals: .name)
                        .frame(maxWidth: 200)
                }
                Divider().padding(.leading, 16)
                sheetRow("Monthly Amount ($)", field: .amount) {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.trailing)
                        .focused($focused, equals: .amount)
                        .frame(width: 100)
                }

                if paymentType == .manualPay {
                    Divider().padding(.leading, 16)
                    sheetRow("Due Day", field: .dueDay) {
                        TextField("1–31", text: $dueDayText)
                            .keyboardType(.numberPad)
                            .font(.subheadline)
                            .multilineTextAlignment(.trailing)
                            .focused($focused, equals: .dueDay)
                            .frame(width: 44)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            .animation(.easeInOut(duration: 0.2), value: paymentType)

            Spacer()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private func sheetRow<Content: View>(_ label: String, field: Field, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            content()
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
}

// MARK: - Edit Sheet

struct EditBillSheet: View {
    let bill: Bill
    let store: BillStore
    @State private var name: String
    @State private var amountText: String
    @State private var dueDayText: String
    @State private var paymentType: PaymentType
    @Environment(\.dismiss) private var dismiss

    private enum Field: Hashable { case name, amount, dueDay }
    @FocusState private var focused: Field?

    init(bill: Bill, store: BillStore) {
        self.bill = bill
        self.store = store
        _name = State(initialValue: bill.name)
        _amountText = State(initialValue: String(format: "%.2f", bill.monthlyAmount))
        _dueDayText = State(initialValue: bill.dueDay.map { "\($0)" } ?? "")
        _paymentType = State(initialValue: bill.paymentType)
    }

    private var parsedAmount: Double? { Double(amountText.replacingOccurrences(of: ",", with: ".")) }
    private var parsedDueDay: Int? {
        guard let d = Int(dueDayText), d >= 1, d <= 31 else { return nil }
        return d
    }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (parsedAmount ?? 0) > 0 &&
        (paymentType == .autoPay || parsedDueDay != nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            HStack {
                Text("Edit Bill")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Save") {
                    guard let amount = parsedAmount,
                          !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    var updated = bill
                    updated.name = name.trimmingCharacters(in: .whitespaces)
                    updated.monthlyAmount = amount
                    updated.dueDay = paymentType == .manualPay ? parsedDueDay : nil
                    updated.paymentType = paymentType
                    store.update(updated)
                    dismiss()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(canSave ? .wealthGreen : .secondary)
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            VStack(spacing: 0) {
                // Payment type picker
                HStack {
                    Text("Payment")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: $paymentType) {
                        Text("Auto-Pay").tag(PaymentType.autoPay)
                        Text("Manual Pay").tag(PaymentType.manualPay)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().padding(.leading, 16)

                sheetRow("Bill Name", field: .name) {
                    TextField("", text: $name)
                        .font(.subheadline)
                        .multilineTextAlignment(.trailing)
                        .focused($focused, equals: .name)
                        .frame(maxWidth: 200)
                }
                Divider().padding(.leading, 16)
                sheetRow("Monthly Amount ($)", field: .amount) {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.trailing)
                        .focused($focused, equals: .amount)
                        .frame(width: 100)
                }

                if paymentType == .manualPay {
                    Divider().padding(.leading, 16)
                    sheetRow("Due Day", field: .dueDay) {
                        TextField("1–31", text: $dueDayText)
                            .keyboardType(.numberPad)
                            .font(.subheadline)
                            .multilineTextAlignment(.trailing)
                            .focused($focused, equals: .dueDay)
                            .frame(width: 44)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            .animation(.easeInOut(duration: 0.2), value: paymentType)

            Spacer()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private func sheetRow<Content: View>(_ label: String, field: Field, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            content()
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
}
