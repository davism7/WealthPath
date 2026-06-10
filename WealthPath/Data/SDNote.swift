//
//  SDNote.swift
//  WealthPath
//

import Foundation
import SwiftData

@Model
final class SDNote {
    var id: UUID
    var title: String
    var content: String
    var lastEdited: Date
    var sortOrder: Int
    var user: SDUser?

    init(id: UUID = UUID(), title: String = "", content: String = "",
         lastEdited: Date = Date(), sortOrder: Int = 0) {
        self.id = id
        self.title = title
        self.content = content
        self.lastEdited = lastEdited
        self.sortOrder = sortOrder
    }
}
