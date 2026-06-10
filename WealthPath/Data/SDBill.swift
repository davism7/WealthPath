//
//  SDBill.swift
//  WealthPath
//

import Foundation
import SwiftData

@Model
final class SDBill {
    var id: UUID
    var name: String
    var monthlyAmount: Double
    var dueDay: Int?
    var paymentType: String
    var user: SDUser?

    init(id: UUID = UUID(), name: String, monthlyAmount: Double, dueDay: Int? = nil, paymentType: String = "manualPay") {
        self.id = id
        self.name = name
        self.monthlyAmount = monthlyAmount
        self.dueDay = dueDay
        self.paymentType = paymentType
    }
}
