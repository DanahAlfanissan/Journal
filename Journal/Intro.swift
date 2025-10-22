//
//  Intor.swift
//  Journal
//
//  Created by Danah Alfanissn on 28/04/1447 AH.
//

import SwiftUI
import Combine
import AVFoundation

// ===================================================
// كل شيء داخل ملف واحد Intro.swift
// تخزين بسيط بـ AppStorage (JSON)
// ===================================================

struct Intro: View {
    // التخزين
    @AppStorage("notes.v1") private var rawNotes: Data = Data()
    @State private var items: [Item] = []

    // حالة الواجهة
    @State private var search = ""
    @State private var editing: Item? = nil
    @State private var showRecorder = false
    @AppStorage("sortMode") private var sortMode = 1   // 0: Bookmark أولاً، 1: الأحدث أولاً

    // البنفسجي #D4C8FF
    private let accent = Color(red: 212/255, green: 200/255, blue: 255/255)

    // الملاحظات المعروضة
    private var displayed: [Item] {
        var arr = items
        if !search.isEmpty {
            arr = arr.filter { $0.title.localizedCaseInsensitiveContains(search) ||
                               $0.content.localizedCaseInsensitiveContains(search) }
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
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("Journal")
                    .font(.system(size: 34, weight: .bold))

                Spacer(minLength: 0)

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

                    Button { editing = Item(title: "", content: "") } label: {
                        Image(systemName: "plus").font(.system(size: 17, weight: .semibold))
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(.ultraThinMaterial, in: Capsule())   // Glass
                .tint(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Empty / List
            if items.isEmpty && search.isEmpty {
                VStack(spacing: 0) {
                    Image("Splash page2")
                        .resizable().scaledToFit()
                        .frame(width: 150, height: 150)
                    Text("Begin Your Journal")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(accent)
                        .padding(.top, 20).padding(.bottom, 8)
                    Text("Craft your personal diary, tap the\nplus icon to begin")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(displayed) { it in
                        Card(it: it, accent: accent,
                             onBookmark: { toggleBookmark(id: it.id) },
                             onOpen: { editing = it })
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { delete(it) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            // Search glass + mic
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").font(.system(size: 18))
                TextField("Search", text: $search)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                Button { showRecorder = true } label: {
                    Image(systemName: "mic.fill").font(.system(size: 18))
                }
            }
            .foregroundColor(.primary.opacity(0.9))
            .frame(height: 52)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.bottom, 26)
        }
        .onAppear(perform: load)
        .fullScreenCover(item: $editing) { it in
            Editor(it: it, accent: accent) { saved in
                upsert(saved)
                editing = nil
            } onCancel: { editing = nil }
            .ignoresSafeArea(.keyboard)   // يضمن ظهور الكيبورد بدون قص الحواف
        }
        .sheet(isPresented: $showRecorder) {
            RecorderSheet { url in
                upsert(Item(title: "Voice note", content: "", audioURL: url))
            }
        }
    }

    // MARK: Persistence + Actions
    private func load() {
        guard !rawNotes.isEmpty,
              let arr = try? JSONDecoder().decode([Item].self, from: rawNotes) else { return }
        items = arr
    }
    private func save() {
        if let data = try? JSONEncoder().encode(items) { rawNotes = data }
    }
    private func upsert(_ it: Item) {
        if let i = items.firstIndex(where: { $0.id == it.id }) { items[i] = it }
        else { items.insert(it, at: 0) }
        save()
    }
    private func delete(_ it: Item) {
        items.removeAll { $0.id == it.id }
        save()
    }
    private func toggleBookmark(id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].isBookmarked.toggle()
        save()
    }
}

// MARK: - Item (نوع داخلي بسيط)
private struct Item: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var date: Date
    var isBookmarked: Bool
    var audioURL: URL?

    init(id: UUID = UUID(),
         title: String,
         content: String,
         date: Date = .now,
         isBookmarked: Bool = false,
         audioURL: URL? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.date = date
        self.isBookmarked = isBookmarked
        self.audioURL = audioURL
    }
}

// MARK: - Card
private struct Card: View {
    let it: Item
    let accent: Color
    var onBookmark: () -> Void
    var onOpen: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(it.title).font(.system(size: 22, weight: .bold))
                Text(it.date, style: .date)
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                if !it.content.isEmpty {
                    Text(it.content).font(.system(size: 15)).lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 26))
            .onTapGesture { onOpen() }

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

// MARK: - Editor (كيبورد تلقائي + Discard/Keep)
private struct Editor: View {
    @State var it: Item
    let accent: Color
    var onSave: (Item) -> Void
    var onCancel: () -> Void

    @State private var original: Item = .init(title: "", content: "")
    @State private var showDiscard = false
    @FocusState private var focusTitle: Bool
    @FocusState private var focusBody: Bool

    private var hasChanges: Bool {
        it.title.trimmingCharacters(in: .whitespacesAndNewlines) !=
        original.title.trimmingCharacters(in: .whitespacesAndNewlines)
        || it.content != original.content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // شريط علوي
            HStack {
                Button { hasChanges ? (showDiscard = true) : onCancel() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)

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

            // عنوان
            TextField("Title", text: $it.title)
                .font(.system(size: 32, weight: .bold))
                .focused($focusTitle)

            // التاريخ
            Text(it.date, style: .date)
                .font(.system(size: 16, weight: .semibold)).foregroundColor(.secondary)

            // النص
            TextEditor(text: $it.content)
                .font(.system(size: 17))
                .frame(maxHeight: .infinity)
                .focused($focusBody)
        }
        .padding(.horizontal, 20)
        .onAppear {
            original = it
            // نشغّل الكيبورد مباشرة
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusTitle = true
            }
        }
        // يمنع سحب الشاشة إذا في تغييرات
        .interactiveDismissDisabled(hasChanges)
        // Dialog بنفس النمط: زر أحمر + زر رمادي
        .confirmationDialog(
            "Are you sure you want to discard changes on this journal?",
            isPresented: $showDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) { onCancel() }
            Button("Keep Editing", role: .cancel) { /* يرجع للتحرير */ }
        }
        .ignoresSafeArea(.keyboard) // يضمن ظهور الكيبورد بالكامل
    }
}

// MARK: - Recorder (اختياري)
private struct RecorderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var r = Rec()
    @State private var url: URL?
    var onUse: (URL) -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("Voice Recorder").font(.headline)
            HStack(spacing: 16) {
                if r.isRecording {
                    Button { r.stop(); url = r.fileURL } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }.tint(.red)
                } else {
                    Button {
                        do { try r.start(); url = r.fileURL } catch { print(error) }
                    } label: {
                        Label("Record", systemImage: "circle.fill")
                    }.tint(.green)
                }
                Spacer()
                Button {
                    if let u = url { onUse(u); dismiss() }
                } label: { Label("Use", systemImage: "checkmark") }
                .disabled(url == nil || r.isRecording)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .presentationDetents([.fraction(0.30), .medium])
    }
}

private final class Rec: NSObject, ObservableObject {
    @Published var isRecording = false
    private var recorder: AVAudioRecorder?
    private(set) var fileURL: URL?

    func start() throws {
        let s = AVAudioSession.sharedInstance()
        try s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try s.setActive(true)
        let u = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("rec_\(UUID().uuidString.prefix(8)).m4a")
        let set: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let rec = try AVAudioRecorder(url: u, settings: set)
        rec.record()
        recorder = rec
        fileURL = u
        isRecording = true
    }

    func stop() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

#Preview { Intro() }
