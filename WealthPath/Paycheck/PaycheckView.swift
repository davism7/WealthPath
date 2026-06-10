//
//  PaycheckView.swift
//  WealthPath
//
//  Created by Davis Morales on 6/1/26.
//

import SwiftUI

struct PaycheckView: View {
    let store: PaycheckStore
    @State private var showAddSheet = false
    @State private var editingPaycheck: Paycheck? = nil

    private var grouped: [(String, [Paycheck])] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        let groups = Dictionary(grouping: store.paychecks) { fmt.string(from: $0.date) }
        return groups.sorted {
            let df = DateFormatter()
            df.dateFormat = "MMMM yyyy"
            return (df.date(from: $0.key) ?? .distantPast) > (df.date(from: $1.key) ?? .distantPast)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.paychecks.isEmpty {
                    emptyStateView
                } else {
                    paycheckList
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
            AddPaycheckSheet(store: store)
        }
        .sheet(item: $editingPaycheck) { p in
            EditPaycheckSheet(paycheck: p, store: store)
        }
    }

    private var paycheckList: some View {
        List {
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("This Month")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(store.currentMonthTotal, format: .currency(code: "USD"))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                }
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(Date(), format: .dateTime.month(.wide).year())
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.wealthGreen)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.wealthGreen.opacity(0.1))
                .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 6, trailing: 16))

            Text("Paychecks")
                .font(.headline)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))

            ForEach(grouped, id: \.0) { _, paychecks in
                ForEach(paychecks) { paycheck in
                    PaycheckRow(paycheck: paycheck)
                        .contentShape(Rectangle())
                        .onTapGesture { editingPaycheck = paycheck }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
                .onDelete { store.delete(at: $0, in: paychecks) }
            }
        }
        .listStyle(.plain)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "banknote")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.secondary.opacity(0.4))
                .padding(.bottom, 6)
            Text("No Paychecks Yet")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
            Text("Tap + to log your first deposit")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PaycheckRow: View {
    let paycheck: Paycheck

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(paycheck.amount, format: .currency(code: "USD"))
                    .font(.headline)
                Text(paycheck.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
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

struct AddPaycheckSheet: View {
    let store: PaycheckStore
    @State private var amountText = ""
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    private var parsedAmount: Double? { Double(amountText.replacingOccurrences(of: ",", with: ".")) }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            Text("Add Paycheck")
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
                if let amount = parsedAmount, amount > 0 {
                    store.add(Paycheck(date: Date(), amount: amount))
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

// MARK: - Edit Sheet

struct EditPaycheckSheet: View {
    let paycheck: Paycheck
    let store: PaycheckStore
    @State private var amountText: String
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    init(paycheck: Paycheck, store: PaycheckStore) {
        self.paycheck = paycheck
        self.store = store
        _amountText = State(initialValue: String(format: "%.2f", paycheck.amount))
    }

    private var parsedAmount: Double? { Double(amountText.replacingOccurrences(of: ",", with: ".")) }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            Text("Edit Paycheck")
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
                if let amount = parsedAmount, amount > 0 {
                    var updated = paycheck
                    updated.amount = amount
                    store.update(updated)
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
