//
//  SDPaycheck.swift
//  WealthPath
//

import Foundation
import SwiftData

@Model
final class SDPaycheck {
    var id: UUID
    var date: Date
    var amount: Double
    var user: SDUser?

    init(id: UUID = UUID(), date: Date, amount: Double) {
        self.id = id
        self.date = date
        self.amount = amount
    }
}
