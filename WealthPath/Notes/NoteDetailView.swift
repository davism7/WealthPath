//
//  NoteDetailView.swift
//  WealthPath
//
//  Created by Davis Morales on 6/1/26.
//

import SwiftUI

struct NoteDetailView: View {
    let noteID: UUID
    let store: NotesStore

    @State private var title = ""
    @State private var content = ""
    @State private var lastEdited = Date()

    var formattedLastEdited: String {
        if Calendar.current.isDateInToday(lastEdited) {
            return "Edited today at " + lastEdited.formatted(date: .omitted, time: .shortened)
        }
        return "Edited " + lastEdited.formatted(date: .long, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Title", text: $title, axis: .vertical)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .onChange(of: title) { _, _ in save() }

            Text(formattedLastEdited)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 6)

            Divider()
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

            TextEditor(text: $content)
                .font(.body)
                .lineSpacing(8)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
                .onChange(of: content) { oldValue, newValue in
                    // "- " at line start → indented bullet
                    if newValue == "- " || newValue.hasSuffix("\n- ") {
                        content = String(newValue.dropLast(2)) + "\t• "
                        return
                    }

                    // Enter on a bullet line
                    if newValue.hasSuffix("\n"), newValue.count == oldValue.count + 1 {
                        let lines = newValue.components(separatedBy: "\n")
                        if lines.count >= 2 {
                            let prevLine = lines[lines.count - 2]
                            if prevLine == "\t• " {
                                // Empty bullet — remove it
                                content = String(newValue.dropLast(prevLine.count + 1))
                                return
                            } else if prevLine.hasPrefix("\t• ") {
                                // Non-empty bullet — continue the list
                                content = newValue + "\t• "
                                return
                            }
                        }
                    }

                    save()
                }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let note = store.notes.first(where: { $0.id == noteID }) {
                title = note.title
                content = note.content
                lastEdited = note.lastEdited
            }
        }
    }

    private func save() {
        lastEdited = Date()
        store.update(id: noteID, title: title, content: content)
    }
}
