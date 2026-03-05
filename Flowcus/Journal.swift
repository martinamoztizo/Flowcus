//
//  Journal.swift
//  Flowcus
//

import SwiftUI
import SwiftData

// MARK: - Journal View
struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.timestamp, order: .reverse) private var entries: [JournalEntry]
    
    @State private var showingAddSheet = false
    @State private var editingEntry: JournalEntry? // Tracks selection
    
    // SMART EMOJI ENGINE: Calculates top 5 used emojis based on Frequency + Recency
    var topEmojis: [String] {
        let defaults = ["🔥", "🙂", "😐", "😫", "🧠"]
        if entries.isEmpty { return defaults }
        
        // Track both the total count and the most recent timestamp for each emoji
        var stats: [String: (count: Int, lastUsed: Date)] = [:]
        
        for entry in entries {
            if let existing = stats[entry.mood] {
                stats[entry.mood] = (count: existing.count + 1, lastUsed: max(existing.lastUsed, entry.timestamp))
            } else {
                stats[entry.mood] = (count: 1, lastUsed: entry.timestamp)
            }
        }
        
        // Sort highest count first. If tied, most recently used wins.
        let sorted = stats.sorted {
            if $0.value.count == $1.value.count {
                return $0.value.lastUsed > $1.value.lastUsed // Recency tie-breaker
            }
            return $0.value.count > $1.value.count // Frequency sort
        }.map { $0.key }
        
        // Take the top 5, pad with defaults if necessary
        var result = Array(sorted.prefix(5))
        for emoji in defaults where result.count < 5 && !result.contains(emoji) {
            result.append(emoji)
        }
        return result
    }
    
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
                                
                                Text(entry.mood) // Directly uses the saved emoji
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            // Sheet for ADDING (entry is nil)
            .sheet(isPresented: $showingAddSheet) {
                JournalEditorView(entry: nil, recommendedEmojis: topEmojis)
            }
            // Sheet for EDITING (entry is passed)
            .sheet(item: $editingEntry) { entry in
                JournalEditorView(entry: entry, recommendedEmojis: topEmojis)
            }
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "Empty Journal",
                        systemImage: "book",
                        description: Text("Write down your progress.")
                    )
                }
            }
        }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(entries[index])
            }
        }
    }
}

// MARK: - JOURNAL EDITOR VIEW (Formerly AddJournalView)
struct JournalEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    // Optional Entry for Editing Mode
    var entry: JournalEntry?
    var recommendedEmojis: [String] // Passed down from parent's Smart Emoji Engine
    
    @State private var title: String = ""
    @State private var text: String = ""
    @State private var selectedMood: String = JournalEntry.defaultMood
    @FocusState private var isTitleFocused: Bool // Track focus for the title
    
    // EMOJI PICKER STATE
    @State private var showEmojiPicker = false
    
    // OPTIMIZATION: Computed property ensures math is done outside the UI redraw cycle
    var displayEmojis: [String] {
        var combined = [selectedMood] // Guarantee active mood is always visible first
        for emoji in recommendedEmojis where emoji != selectedMood {
            combined.append(emoji)
        }
        return combined
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Editable Title Area
                ZStack(alignment: .leading) {
                    if title.isEmpty && !isTitleFocused {
                        Text("New Entry")
                            .font(.title.bold())
                            .foregroundStyle(.primary)
                    }

                    TextField("", text: $title)
                        .font(.title.bold())
                        .focused($isTitleFocused)
                        .foregroundStyle(.primary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 0, trailing: 20))

                // Mood Bar
                Section {
                    HStack(spacing: 8) {
                        // 1. THE SMART LIST
                        ForEach(displayEmojis, id: \.self) { mood in
                            Button(action: {
                                withAnimation(.snappy) { selectedMood = mood }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }) {
                                Text(mood)
                                    .font(.title3)
                                    .frame(width: 36, height: 36)
                                    .background(selectedMood == mood ? Color.cardinalRed.opacity(0.15) : Color.clear)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .contentShape(Circle())
                        }

                        // 2. THE '+' BUTTON (Opens Emoji Picker)
                        Button(action: { showEmojiPicker = true }) {
                            Image(systemName: "plus")
                                .font(.body)
                                .foregroundStyle(.gray)
                                .frame(width: 36, height: 36)
                                .background(Color(.systemGray6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                        .popover(isPresented: $showEmojiPicker, arrowEdge: .top) {
                            EmojiPickerView { emoji in
                                withAnimation(.snappy) { selectedMood = emoji }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showEmojiPicker = false
                            }
                            .presentationCompactAdaptation(.popover)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }

                // Log
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 400)
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
                    selectedMood = entry.mood // Directly assigns the saved emoji
                } else {
                    // Start empty so the placeholder "New Entry" shows and disappears on type
                    title = ""
                    // Default to their #1 most used emoji instead of a hardcoded "😐"
                    selectedMood = recommendedEmojis.first ?? JournalEntry.defaultMood
                }
            }
        }
    }
    
    private func save() {
        if let entry = entry {
            // Update Existing
            entry.title = title
            entry.content = text
            entry.mood = selectedMood // Directly sets the string
        } else {
            // Create New
            modelContext.insert(JournalEntry(title: title, content: text, mood: selectedMood))
        }
    }
}

// MARK: - EMOJI PICKER VIEW
struct EmojiPickerView: View {
    let onSelect: (String) -> Void
    @State private var selectedCategory = 0

    var body: some View {
        VStack(spacing: 0) {
            // Category tab bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(emojiCategories.indices, id: \.self) { index in
                        Button {
                            withAnimation(.snappy) { selectedCategory = index }
                        } label: {
                            Image(systemName: emojiCategories[index].symbol)
                                .font(.caption)
                                .padding(8)
                                .foregroundStyle(selectedCategory == index ? Color.cardinalRed : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 36)

            Divider()

            // Grid for active category only
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 4) {
                    ForEach(emojiCategories[selectedCategory].emojis, id: \.self) { emoji in
                        Text(emoji)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(emoji) }
                    }
                }
                .padding(8)
            }
        }
        .frame(width: 300, height: 280)
    }
}


