//
//  SDBillChecklist.swift
//  WealthPath
//

import Foundation
import SwiftData

@Model
final class SDBillChecklist {
    var id: UUID
    var billID: UUID
    var monthKey: String
    var isPaid: Bool
    var user: SDUser?

    init(id: UUID = UUID(), billID: UUID, monthKey: String, isPaid: Bool = false) {
        self.id = id
        self.billID = billID
        self.monthKey = monthKey
        self.isPaid = isPaid
    }
}
