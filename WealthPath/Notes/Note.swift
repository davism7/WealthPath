//
//  Note.swift
//  WealthPath
//

import Foundation
import SwiftUI
import Observation
import SwiftData

struct Note: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var lastEdited: Date = Date()

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New Note" : title
    }

    var formattedDate: String {
        if Calendar.current.isDateInToday(lastEdited) {
            return lastEdited.formatted(date: .omitted, time: .shortened)
        }
        return lastEdited.formatted(date: .abbreviated, time: .omitted)
    }
}

@Observable
@MainActor
final class NotesStore {
    private let modelContext: ModelContext
    private let uid: String
    private let sync: FirestoreSyncManager

    private(set) var notes: [Note] = []

    init(modelContext: ModelContext, uid: String, sync: FirestoreSyncManager) {
        self.modelContext = modelContext
        self.uid = uid
        self.sync = sync
        load()
        Task { @MainActor in
            for await _ in NotificationCenter.default.notifications(named: .wealthPathDataSynced) {
                self.load()
            }
        }
    }

    @discardableResult
    func addNote() -> Note {
        guard let user = fetchUser() else { return Note() }
        let note = Note()
        let minOrder = user.notes.map { $0.sortOrder }.min() ?? 0
        let sd = SDNote(id: note.id, title: note.title, content: note.content,
                        lastEdited: note.lastEdited, sortOrder: minOrder - 1)
        sd.user = user
        modelContext.insert(sd)
        persist()
        sync.pushNote(sd, uid: uid)
        load()
        return notes.first(where: { $0.id == note.id }) ?? note
    }

    func update(id: UUID, title: String, content: String) {
        guard let sd = fetchSD(id: id) else { return }
        sd.title = title
        sd.content = content
        sd.lastEdited = Date()
        persist()
        sync.pushNote(sd, uid: uid)
        if let i = notes.firstIndex(where: { $0.id == id }) {
            notes[i].title = title
            notes[i].content = content
            notes[i].lastEdited = sd.lastEdited
        }
    }

    func delete(id: UUID) {
        guard let sd = fetchSD(id: id) else { return }
        sync.deleteNote(id: id, uid: uid)
        modelContext.delete(sd)
        persist()
        notes.removeAll { $0.id == id }
    }

    func move(from source: IndexSet, to destination: Int) {
        var reordered = notes
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, note) in reordered.enumerated() {
            if let sd = fetchSD(id: note.id) {
                sd.sortOrder = index
                sync.pushNote(sd, uid: uid)
            }
        }
        persist()
        notes = reordered
    }

    func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { notes[$0] }
        for note in toDelete {
            if let sd = fetchSD(id: note.id) {
                sync.deleteNote(id: note.id, uid: uid)
                modelContext.delete(sd)
            }
        }
        persist()
        for note in toDelete { notes.removeAll { $0.id == note.id } }
    }

    private func fetchUser() -> SDUser? {
        let descriptor = FetchDescriptor<SDUser>(predicate: #Predicate { $0.firebaseUID == uid })
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchSD(id: UUID) -> SDNote? {
        let descriptor = FetchDescriptor<SDNote>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private func persist() { try? modelContext.save() }

    private func load() {
        guard let user = fetchUser() else { notes = []; return }
        notes = user.notes
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { Note(id: $0.id, title: $0.title, content: $0.content, lastEdited: $0.lastEdited) }
    }
}
