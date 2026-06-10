//
//  SDContribution.swift
//  WealthPath
//

import Foundation
import SwiftData

@Model
final class SDContribution {
    var id: UUID
    var amount: Double
    var date: Date
    var savingsAccount: SDSavingsAccount?

    init(id: UUID = UUID(), amount: Double, date: Date = Date()) {
        self.id = id
        self.amount = amount
        self.date = date
    }
}
