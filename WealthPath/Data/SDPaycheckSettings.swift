//
//  SDPaycheckSettings.swift
//  WealthPath
//

import Foundation
import SwiftData

@Model
final class SDPaycheckSettings {
    var id: UUID
    var user: SDUser?

    @Relationship(deleteRule: .cascade, inverse: \SDAllocation.settings)
    var allocations: [SDAllocation] = []

    init(id: UUID = UUID()) {
        self.id = id
    }
}
