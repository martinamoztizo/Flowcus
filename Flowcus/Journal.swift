//
//  Journal.swift
//  Flowcus
//

import SwiftUI
import SwiftData

// MARK: - 3. JOURNAL VIEW (TITLE SUPPORT)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddSheet = true }) { Image(systemName: "square.and.pencil") }
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
    var recommendedEmojis: [String] // Passed down from parent's Smart Emoji Engine
    
    @State private var title: String = ""
    @State private var text: String = ""
    @State private var selectedMood: String = "😐"
    @FocusState private var isTitleFocused: Bool // Track focus for the title
    
    // HIDDEN KEYBOARD TRICK STATE
    @State private var customEmojiInput: String = ""
    @FocusState private var isEmojiKeyboardFocused: Bool
    
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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            // 1. THE SMART LIST
                            ForEach(displayEmojis, id: \.self) { mood in
                                Button(action: {
                                    withAnimation(.snappy) { selectedMood = mood }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }) {
                                    Text(mood)
                                        .font(.largeTitle)
                                        .frame(width: 50, height: 50)
                                        .background(selectedMood == mood ? Color.cardinalRed.opacity(0.15) : Color.clear)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .contentShape(Circle())
                            }
                            
                            // 2. THE '+' PLACEHOLDER (Triggers Keyboard)
                            Button(action: {
                                customEmojiInput = "" // Clear previous input
                                isEmojiKeyboardFocused = true // Summon Keyboard
                            }) {
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .foregroundStyle(.gray)
                                    .frame(width: 50, height: 50)
                                    .background(Color(.systemGray6))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .contentShape(Circle())
                            // The invisible text field that forces the keyboard open
                            .background(
                                TextField("", text: $customEmojiInput)
                                    .focused($isEmojiKeyboardFocused)
                                    .opacity(0)
                                    .frame(width: 0, height: 0)
                                    // Intercept the typing instantly
                                    .onChange(of: customEmojiInput) { _, newValue in
                                        if let firstChar = newValue.first {
                                            withAnimation(.snappy) { selectedMood = String(firstChar) }
                                            isEmojiKeyboardFocused = false // Dismiss keyboard
                                            customEmojiInput = ""
                                        }
                                    }
                            )
                        }
                        .padding(.horizontal, 20) // Aligns with default Form padding
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets()) // Allows edge-to-edge scrolling
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
                    selectedMood = entry.mood // Directly assigns the saved emoji
                } else {
                    // Start empty so the placeholder "New Entry" shows and disappears on type
                    title = ""
                    // Default to their #1 most used emoji instead of a hardcoded "😐"
                    selectedMood = recommendedEmojis.first ?? "😐"
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


