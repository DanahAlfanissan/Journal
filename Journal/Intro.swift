//
//  Intor.swift
//  Journal
//
//  Created by Danah Alfanissn on 28/04/1447 AH.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Model
struct JournalNote: Identifiable, Codable, Equatable {
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

// MARK: - Store (UserDefaults)
final class JournalStoreLocal: ObservableObject {
    @Published var notes: [JournalNote] = [] { didSet { save() } }
    private let key = "journal.notes.v1"

    init() { load() }

    func add(_ n: JournalNote) { notes.insert(n, at: 0) }
    func update(_ n: JournalNote) { if let i = notes.firstIndex(where: {$0.id == n.id}) { notes[i] = n } }
    func delete(_ n: JournalNote) { notes.removeAll { $0.id == n.id } }
    func toggleBookmark(_ n: JournalNote) { if let i = notes.firstIndex(of: n) { notes[i].isBookmarked.toggle() } }

    private func save() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr  = try? JSONDecoder().decode([JournalNote].self, from: data) else { return }
        notes = arr
    }
}

// MARK: - Audio (separate voice-note)
final class JournalAudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    private var recorder: AVAudioRecorder?
    private(set) var lastURL: URL?

    func requestPermission(_ done: @escaping (Bool)->Void) {
        AVAudioApplication.requestRecordPermission { ok in
            DispatchQueue.main.async { done(ok) }
        }
    }
    func start() throws {
        let s = AVAudioSession.sharedInstance()
        try s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try s.setActive(true, options: .notifyOthersOnDeactivation)
        let url = Self.fileURL()
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let r = try AVAudioRecorder(url: url, settings: settings)
        r.delegate = self
        r.record()
        recorder = r
        lastURL = url
        isRecording = true
    }
    func stop() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    private static func fileURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("rec_\(UUID().uuidString.prefix(8)).m4a")
    }
}

// MARK: - Intro
private enum SortMode: Int { case bookmarkFirst, entryDate }

struct Intro: View {
    @StateObject private var store = JournalStoreLocal()

    @State private var search = ""
    @State private var editingNote: JournalNote? = nil      // item binding = لا شاشة سوداء
    @State private var showRecorder = false
    @AppStorage("sortMode") private var sortModeRaw: Int = SortMode.entryDate.rawValue

    private var sortMode: SortMode { SortMode(rawValue: sortModeRaw) ?? .entryDate }
    private let accent = Color(red: 212/255, green: 200/255, blue: 255/255) // #D4C8FF

    private var displayed: [JournalNote] {
        var arr = store.notes
        if !search.isEmpty {
            arr = arr.filter { $0.title.localizedCaseInsensitiveContains(search) || $0.content.localizedCaseInsensitiveContains(search) }
        }
        switch sortMode {
        case .bookmarkFirst: arr.sort { ($0.isBookmarked ? 0 : 1, $0.date) < ($1.isBookmarked ? 0 : 1, $1.date) }
        case .entryDate:     arr.sort { $0.date > $1.date }
        }
        return arr
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.97).ignoresSafeArea()
            VStack(spacing: 0) {

                // Header
                HStack {
                    Text("Journal")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.leading, 20)

                    Spacer()

                    HStack(spacing: 16) {
                        Menu {
                            Picker("Sort", selection: $sortModeRaw) {
                                Text("Sort by Bookmark").tag(SortMode.bookmarkFirst.rawValue)
                                Text("Sort by Entry Date").tag(SortMode.entryDate.rawValue)
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .menuIndicator(.hidden)

                        Button {
                            editingNote = JournalNote(title: "", content: "", isBookmarked: false)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(height: 44)
                    .padding(.horizontal, 16)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.trailing, 20)
                }
                .padding(.top, 12)

                Spacer().frame(height: 80)

                // List or Empty
                if store.notes.isEmpty && search.isEmpty {
                    EmptyStateView(accent: accent)
                } else {
                    List {
                        ForEach(displayed) { n in
                            Button { editingNote = n } label: {
                                JournalCard(note: n, accent: accent)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { store.delete(n) } label: {
                                    Label("Delete", systemImage: "trash")
                                }.tint(.red)
                            }
                            .swipeActions(edge: .leading) {
                                Button { store.toggleBookmark(n) } label: {
                                    Label("Mark", systemImage: n.isBookmarked ? "bookmark.slash" : "bookmark")
                                }.tint(.purple)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }

                Spacer()

                // Search Glass + Mic
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").font(.system(size: 18))
                    TextField("Search", text: $search)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    Button { showRecorder = true } label: {
                        Image(systemName: "mic.fill").font(.system(size: 18))
                    }
                }
                .foregroundColor(.white.opacity(0.9))
                .frame(height: 52)
                .padding(.horizontal, 16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.07), lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.bottom, 26)
            }
        }
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.medium)

        // Editor (item binding)
        .fullScreenCover(item: $editingNote) { note in
            JournalEditView(note: note) { saved in
                if store.notes.contains(where: { $0.id == saved.id }) { store.update(saved) }
                else { store.add(saved) }
                editingNote = nil
            } onCancel: {
                editingNote = nil
            }
        }

        // Voice note sheet (creates separate note)
        .sheet(isPresented: $showRecorder) {
            VoiceRecorderSheet { url in
                store.add(JournalNote(title: "Voice note", content: "", audioURL: url))
            }
        }
    }
}

// MARK: - Empty State
private struct EmptyStateView: View {
    let accent: Color
    var body: some View {
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
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .kerning(0.6).lineSpacing(1)
                .padding(.top, 4)
        }
    }
}

// MARK: - Card Cell
private struct JournalCard: View {
    let note: JournalNote
    let accent: Color
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(note.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(note.date.formatted(date: .numeric, time: .omitted))
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 14, weight: .semibold))
                if !note.content.isEmpty {
                    Text(note.content)
                        .foregroundColor(.white)
                        .font(.system(size: 15))
                        .lineLimit(3)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.08), lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
            )
            if note.isBookmarked {
                Image(systemName: "bookmark.fill")
                    .foregroundColor(accent)
                    .padding(14)
            }
        }
    }
}

// MARK: - Editor (X + purple ✓) + auto keyboard
private struct JournalEditView: View {
    @State var note: JournalNote
    var onSave: (JournalNote) -> Void
    var onCancel: () -> Void

    @FocusState private var focus: Field?
    private enum Field { case content }

    var body: some View {
        ZStack {
            Color.black.opacity(0.97).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button(role: .cancel) { onCancel() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                    Button {
                        note.title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(note)
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.purple, in: Circle())
                    }
                    .disabled(note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                TextField("Title", text: $note.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text(note.date.formatted(date: .numeric, time: .omitted))
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 16, weight: .semibold))

                TextEditor(text: $note.content)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .frame(maxHeight: .infinity)
                    .focused($focus, equals: .content)

                HStack {
                    Image(systemName: note.isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(note.isBookmarked ? .purple : .white)
                        .onTapGesture { note.isBookmarked.toggle() }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focus = .content }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Voice Recorder Sheet
private struct VoiceRecorderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var rec = JournalAudioRecorder()
    @State private var fileURL: URL?
    var onFinish: (URL) -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("Voice Recorder").font(.headline)
            HStack(spacing: 16) {
                if rec.isRecording {
                    Button { rec.stop(); fileURL = rec.lastURL } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }.tint(.red)
                } else {
                    Button {
                        // في Preview نولّد ملف وهمي، في التشغيل نسجّل فعلي
                        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                            let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dummy.m4a")
                            try? Data([0]).write(to: tmp, options: .atomic)
                            fileURL = tmp
                        } else {
                            rec.requestPermission { ok in
                                guard ok else { return }
                                do { try rec.start(); fileURL = rec.lastURL } catch { print(error) }
                            }
                        }
                    } label: { Label("Record", systemImage: "circle.fill") }
                    .tint(.green)
                }
                Spacer()
                Button {
                    if let url = fileURL { onFinish(url); dismiss() }
                } label: { Label("Use", systemImage: "checkmark") }
                .disabled(fileURL == nil || rec.isRecording)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .presentationDetents([.fraction(0.30), .medium])
    }
}

// MARK: - Preview
#Preview {
    Intro()
}
