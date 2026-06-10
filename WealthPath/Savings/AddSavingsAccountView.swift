//
//  AddSavingsAccountView.swift
//  WealthPath
//
//  Created by Davis Morales on 6/1/26.
//

import SwiftUI

struct AddSavingsAccountView: View {
    let store: SavingsStore

    @State private var name = ""
    @State private var startingBalanceText = ""
    @State private var returnRateText = ""
    @Environment(\.dismiss) private var dismiss

    private enum Field { case name, startingBalance, returnRate }
    @FocusState private var focused: Field?

    private var startingBalance: Double? { Double(startingBalanceText.replacingOccurrences(of: ",", with: ".")) }
    private var returnRate: Double? { Double(returnRateText.replacingOccurrences(of: ",", with: ".")) }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (startingBalance ?? -1) >= 0 &&
        (returnRate ?? -1) >= 0
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            Text("New Account")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            VStack(spacing: 0) {
                inputRow("Account Name", placeholder: "e.g. Roth IRA", text: $name, keyboard: .default, field: .name)
                Divider().padding(.leading, 16)
                inputRow("Current Balance ($)", placeholder: "0.00", text: $startingBalanceText, keyboard: .decimalPad, field: .startingBalance)
                Divider().padding(.leading, 16)
                inputRow("Annual Rate (%)", placeholder: "0.0", text: $returnRateText, keyboard: .decimalPad, field: .returnRate)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Button { createAccount() } label: {
                Text("Create Account")
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
    private func inputRow(_ label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType, field: Field) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            TextField(placeholder, text: text)
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

    private func createAccount() {
        guard let startBal = startingBalance,
              let rate = returnRate,
              !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        store.add(SavingsAccount(
            name: name.trimmingCharacters(in: .whitespaces),
            startingBalance: startBal,
            annualReturnRate: rate / 100.0
        ))
        dismiss()
    }
}
