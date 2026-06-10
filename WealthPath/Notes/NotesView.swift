//
//  NotesView.swift
//  WealthPath
//

import SwiftUI

struct NotesView: View {
    let store: NotesStore

    @State private var path: [UUID] = []
    @State private var showGuide = false

    var body: some View {
        NavigationStack(path: $path) {
            noteListView
                .navigationTitle("")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            let note = store.addNote()
                            path.append(note.id)
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .fontWeight(.semibold)
                        }
                    }
                }
                .navigationDestination(for: UUID.self) { id in
                    NoteDetailView(noteID: id, store: store)
                }
                .navigationDestination(isPresented: $showGuide) {
                    SavingsGuideView()
                }
        }
    }

    private var noteListView: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundColor(.wealthGreen)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Savings & Investing Guide")
                            .font(.headline)
                            .lineLimit(1)
                        Text("Recommended allocations by bill percentage")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture { showGuide = true }
                .deleteDisabled(true)
                .moveDisabled(true)
            }

            if !store.notes.isEmpty {
                Section {
                    ForEach(store.notes) { note in
                        Button {
                            path.append(note.id)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.displayTitle)
                                        .font(.headline)
                                        .lineLimit(1)
                                    HStack(spacing: 6) {
                                        Text(note.formattedDate)
                                            .foregroundColor(.secondary)
                                        if !note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            Text("·").foregroundColor(.secondary)
                                            Text(note.content)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .font(.subheadline)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(Color(.tertiaryLabel))
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { store.delete(at: $0) }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
