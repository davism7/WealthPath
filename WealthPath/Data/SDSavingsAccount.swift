//
//  SDSavingsAccount.swift
//  WealthPath
//

import Foundation
import SwiftData

@Model
final class SDSavingsAccount {
    var id: UUID
    var name: String
    var startingBalance: Double
    var annualReturnRate: Double
    var createdDate: Date
    var balanceAdjustment: Double
    var completedPeriodsData: Data
    var user: SDUser?

    @Relationship(deleteRule: .cascade, inverse: \SDContribution.savingsAccount)
    var contributions: [SDContribution] = []

    init(id: UUID = UUID(), name: String, startingBalance: Double, annualReturnRate: Double,
         createdDate: Date = Date(), balanceAdjustment: Double = 0, completedPeriods: Set<String> = []) {
        self.id = id
        self.name = name
        self.startingBalance = startingBalance
        self.annualReturnRate = annualReturnRate
        self.createdDate = createdDate
        self.balanceAdjustment = balanceAdjustment
        self.completedPeriodsData = (try? JSONEncoder().encode(Array(completedPeriods))) ?? Data()
    }

    var completedPeriods: Set<String> {
        get {
            let array = (try? JSONDecoder().decode([String].self, from: completedPeriodsData)) ?? []
            return Set(array)
        }
        set {
            completedPeriodsData = (try? JSONEncoder().encode(Array(newValue))) ?? Data()
        }
    }
}
