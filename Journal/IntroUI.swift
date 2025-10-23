//
//  IntroUI.swift
//  Journal
//
//  Created by Danah Alfanissn on 29/04/1447 AH.
//

import SwiftUI

struct IntroUI: View {
    @StateObject private var model = IntroModel()
    private let mic = IntroRecorder()

    @State private var search = ""
    @AppStorage("intro.sortMode") private var sortMode = 1
    @State private var editing: IntroNote? = nil
    @State private var toDelete: IntroNote? = nil
    @State private var showDeleteAlert = false
    @State private var isRecording = false

    private let accent = Color(red: 212/255, green: 200/255, blue: 255/255)

    private var displayed: [IntroNote] {
        var arr = model.notes
        if !search.isEmpty {
            arr = arr.filter { $0.title.localizedCaseInsensitiveContains(search) || $0.content.localizedCaseInsensitiveContains(search) }
        }
        if sortMode == 0 {
            arr.sort { ($0.isBookmarked ? 0:1, $0.date) < ($1.isBookmarked ? 0:1, $1.date) }
        } else {
            arr.sort { $0.date > $1.date }
        }
        return arr
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            HStack(alignment: .firstTextBaseline) {
                Text("Journal")
                    .font(.system(size: 34, weight: .bold))
                Spacer()
                HStack(spacing: 18) {
                    Menu {
                        Picker("Sort", selection: $sortMode) {
                            Text("Sort by Bookmark").tag(0)
                            Text("Sort by Entry Date").tag(1)
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .menuIndicator(.hidden)

                    Button {
                        editing = IntroNote(title: "", content: "")
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(.ultraThinMaterial, in: Capsule())
                .tint(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // MARK: Empty State or List
            if model.notes.isEmpty && search.isEmpty {
                EmptyState(accent: accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(displayed) { it in
                        Card(it: it, accent: accent,
                             onBookmark: { model.toggleBookmark(id: it.id) },
                             onOpen: { editing = it },
                             onDelete: { toDelete = it; showDeleteAlert = true })
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            // MARK: Search + Mic
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(size: 16))
                TextField("Search", text: $search)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                Button {
                    if isRecording {
                        mic.stop()
                        isRecording = false
                        if let url = mic.fileURL { model.addVoiceNote(from: url) }
                    } else {
                        do { try mic.start(); isRecording = true }
                        catch { print("Recording error:", error) }
                    }
                } label: {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(isRecording ? .red : .primary)
                }
            }
            .foregroundColor(.primary.opacity(0.9))
            .frame(height: 44)
            .padding(.horizontal, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        // MARK: Editor
        .fullScreenCover(item: $editing) { it in
            Editor(it: it, accent: accent) { saved in
                model.upsert(saved)
                editing = nil
            } onCancel: {
                editing = nil
            }
            .ignoresSafeArea(.keyboard)
        }
        // MARK: Delete Confirm
        .alert(
            "Delete Journal?",
            isPresented: $showDeleteAlert,
            presenting: toDelete,
            actions: { it in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { model.delete(it) }
            },
            message: { _ in
                Text("Are you sure you want to delete this journal?")
            }
        )
    }
}

// MARK: - Subviews

private struct EmptyState: View {
    let accent: Color
    var body: some View {
        VStack(spacing: 0) {
            Image("Splash page2")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
            Text("Begin Your Journal")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(accent)
                .padding(.top, 20)
                .padding(.bottom, 8)
            Text("Craft your personal diary, tap the\nplus icon to begin")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }
}

private struct Card: View {
    let it: IntroNote
    let accent: Color
    var onBookmark: () -> Void
    var onOpen: () -> Void
    var onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(it.title)
                    .font(.system(size: 22, weight: .bold))
                Text(it.date, style: .date)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                if !it.content.isEmpty {
                    Text(it.content)
                        .font(.system(size: 15))
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
            .contentShape(RoundedRectangle(cornerRadius: 26))
            .onTapGesture { onOpen() }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            Button(action: onBookmark) {
                Image(systemName: it.isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(it.isBookmarked ? accent : .primary.opacity(0.9))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }
}

private struct Editor: View {
    @State var it: IntroNote
    let accent: Color
    var onSave: (IntroNote) -> Void
    var onCancel: () -> Void

    @State private var askDiscard = false
    @FocusState private var fTitle: Bool
    @FocusState private var fBody: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button { askDiscard = true } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                Spacer()
                Button {
                    it.title = it.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(it)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(accent, in: Circle())
                }
                .disabled(it.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(it.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            TextField("Title", text: $it.title)
                .font(.system(size: 32, weight: .bold))
                .focused($fTitle)
                .submitLabel(.next)
                .onSubmit { fBody = true }

            Text(it.date, style: .date)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)

            TextEditor(text: $it.content)
                .font(.system(size: 17))
                .frame(maxHeight: .infinity)
                .focused($fBody)
        }
        .padding(.horizontal, 20)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { fTitle = true }
        }
        .alert("Are you sure you want to discard changes on this journal?",
               isPresented: $askDiscard) {
            Button("Discard Changes", role: .destructive) { onCancel() }
            Button("Keep Editing", role: .cancel) { }
        }
        .ignoresSafeArea(.keyboard)
    }
}

#Preview { IntroUI() }
