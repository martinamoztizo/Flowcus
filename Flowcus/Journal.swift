//
//  Journal.swift
//  Flowcus
//

import SwiftUI
import SwiftData

func normalizedMood(_ mood: String) -> String {
    switch mood.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "good":
        return "🙂"
    case "neutral":
        return "😐"
    case "bad":
        return "😫"
    case "focused":
        return "🧠"
    case "great", "excellent", "fire":
        return "🔥"
    default:
        return JournalEntry.allowedMoods.contains(mood) ? mood : "😐"
    }
}

// MARK: - 3. JOURNAL VIEW (TITLE SUPPORT)
struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.timestamp, order: .reverse) private var entries: [JournalEntry]
    
    @State private var showingAddSheet = false
    @State private var editingEntry: JournalEntry? // Tracks selection
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(entries) { entry in
                    // Make the row tappable to Edit
                    Button(action: { editingEntry = entry }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                // Title is now prominent
                                if !entry.title.isEmpty {
                                    Text(entry.title)
                                        .font(.headline)
                                        .lineLimit(1)
                                } else {
                                    Text("Untitled Entry")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(normalizedMood(entry.mood))
                                    .font(.caption).padding(4)
                                    .background(Color(.systemGray6)).cornerRadius(5)
                            }
                            
                            HStack {
                                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            
                            Text(entry.content)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteEntries)
            }
            .navigationTitle("Brain Dump")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddSheet = true }) { Image(systemName: "square.and.pencil") }
                }
            }
            // Sheet for ADDING (entry is nil)
            .sheet(isPresented: $showingAddSheet) {
                JournalEditorView(entry: nil)
            }
            // Sheet for EDITING (entry is passed)
            .sheet(item: $editingEntry) { entry in
                JournalEditorView(entry: entry)
            }
            .overlay {
                if entries.isEmpty { ContentUnavailableView("Empty Journal", systemImage: "book", description: Text("Write down your progress.")) }
            }
        }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        withAnimation { for index in offsets { modelContext.delete(entries[index]) } }
    }
}

// MARK: - JOURNAL EDITOR VIEW (Formerly AddJournalView)
struct JournalEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    // Optional Entry for Editing Mode
    var entry: JournalEntry?
    
    @State private var title: String = ""
    @State private var text: String = ""
    @State private var selectedMood: String = "😐"
    @FocusState private var isTitleFocused: Bool // Track focus for the title
    
    let moods = ["🔥", "🙂", "😐", "😫", "🧠"]
    
    var body: some View {
        NavigationStack {
            Form {
                // Editable Large Title Area
                ZStack(alignment: .leading) {
                    if title.isEmpty && !isTitleFocused {
                        Text("New Entry")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.primary) // 100% Opacity
                    }
                    
                    TextField("", text: $title)
                        .font(.largeTitle.bold())
                        .focused($isTitleFocused)
                        .foregroundStyle(.primary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
                
                Section("Mood") {
                    Picker("Mood", selection: $selectedMood) {
                        ForEach(moods, id: \.self) { mood in Text(mood).tag(mood) }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Log") {
                    TextEditor(text: $text)
                        .frame(minHeight: 250)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("Write your thoughts here...")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let entry = entry {
                    title = entry.title
                    text = entry.content
                    selectedMood = normalizedMood(entry.mood)
                } else {
                    // Start empty so the placeholder "New Entry" shows and disappears on type
                    title = ""
                    selectedMood = "😐"
                }
            }
        }
    }
    
    private func save() {
        if let entry = entry {
            // Update Existing
            entry.title = title
            entry.content = text
            entry.setMood(normalizedMood(selectedMood))
        } else {
            // Create New
            modelContext.insert(JournalEntry(title: title, content: text, mood: normalizedMood(selectedMood)))
        }
    }
}
