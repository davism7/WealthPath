//
//  SDAllocation.swift
//  WealthPath
//

import Foundation
import SwiftData

@Model
final class SDAllocation {
    var id: UUID
    var accountID: UUID
    var percentage: Double
    var settings: SDPaycheckSettings?

    init(id: UUID = UUID(), accountID: UUID, percentage: Double) {
        self.id = id
        self.accountID = accountID
        self.percentage = percentage
    }
}
