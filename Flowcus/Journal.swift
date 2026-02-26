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
    
    // SMART EMOJI ENGINE: Calculates top 5 used emojis on the fly
    var topEmojis: [String] {
        let defaults = ["🔥", "🙂", "😐", "😫", "🧠"]
        if entries.isEmpty { return defaults }
        
        // Group by exact emoji string and count frequencies
        let counts = Dictionary(grouping: entries, by: \.mood).mapValues { $0.count }
        
        // Sort highest to lowest and extract the keys
        let sorted = counts.sorted { $0.value > $1.value }.map { $0.key }
        
        // Take the top 5, pad with defaults if necessary so we always have exactly 5 options
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
                            
                            // 2. THE '+' PLACEHOLDER
                            Button(action: {
                                // Keyboard trigger logic will go here in Step 4
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


