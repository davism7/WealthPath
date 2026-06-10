//
//  SavingsGuideView.swift
//  WealthPath
//
//  Created by Davis Morales on 6/1/26.
//

import SwiftUI

struct SavingsGuideView: View {

    private struct GuideSection {
        let range: String
        let position: String
        let investing: String
        let savings: String
        let total: String
        let note: String
        let color: Color
    }

    private let sections: [GuideSection] = [
        GuideSection(
            range: "Bills Use Less Than 30% of Income",
            position: "Excellent Financial Flexibility",
            investing: "28–32% of income",
            savings: "18–22% of income",
            total: "46–54% of income",
            note: "You have substantial room to accelerate wealth building while maintaining financial flexibility.",
            color: Color(red: 0.18, green: 0.72, blue: 0.48)
        ),
        GuideSection(
            range: "Bills Use 30–50% of Income",
            position: "Strong Financial Position",
            investing: "18–22% of income",
            savings: "13–17% of income",
            total: "31–39% of income",
            note: "A balanced approach that supports both current spending and future financial growth.",
            color: Color(red: 0.30, green: 0.65, blue: 0.95)
        ),
        GuideSection(
            range: "Bills Use 50–70% of Income",
            position: "Average Financial Position",
            investing: "10–14% of income",
            savings: "6–10% of income",
            total: "16–24% of income",
            note: "Focus on consistency. Regular contributions can create meaningful long-term results.",
            color: Color(red: 0.95, green: 0.75, blue: 0.20)
        ),
        GuideSection(
            range: "Bills Use 70–85% of Income",
            position: "Limited Financial Flexibility",
            investing: "6–8% of income",
            savings: "4–6% of income",
            total: "10–14% of income",
            note: "Prioritize building an emergency fund while continuing to make progress toward future goals.",
            color: Color(red: 0.95, green: 0.55, blue: 0.20)
        ),
        GuideSection(
            range: "Bills Use More Than 85% of Income",
            position: "Financial Strain",
            investing: "1–3% of income",
            savings: "2–4% of income",
            total: "3–7% of income",
            note: "Focus on creating financial breathing room. Small contributions can still help build positive habits and momentum.",
            color: Color(red: 0.95, green: 0.38, blue: 0.28)
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommended Savings &")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Investing Allocations")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Use these ranges as a starting point based on how much of your income goes toward bills.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }

                ForEach(sections, id: \.range) { section in
                    guideSectionCard(section)
                }
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func guideSectionCard(_ section: GuideSection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Range heading + position badge
            VStack(alignment: .leading, spacing: 8) {
                Text(section.range)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Text(section.position)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(section.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(section.color.opacity(0.12))
                    .clipShape(Capsule())
            }

            // Allocation rows
            VStack(spacing: 0) {
                allocationRow(label: "Investing", value: section.investing, color: section.color)
                Divider().padding(.leading, 16)
                allocationRow(label: "Savings", value: section.savings, color: section.color)
                Divider().padding(.leading, 16)
                allocationRow(label: "Total Wealth Building", value: section.total, color: section.color)
            }
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Footer note
            Text(section.note)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(section.color.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func allocationRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

#Preview {
    NavigationStack {
        SavingsGuideView()
    }
}
