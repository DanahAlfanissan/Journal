//
//  Intor.swift
//  Journal
//
//  Created by Danah Alfanissn on 28/04/1447 AH.
//

import Foundation
import AVFoundation
import Combine   // مهم عشان ObservableObject

// MARK: - Model
struct IntroNote: Identifiable, Codable, Equatable {
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
final class IntroModel: ObservableObject {
    @Published var notes: [IntroNote] = [] { didSet { save() } }
    private let key = "intro.notes.v1"

    init() { load() }

    func upsert(_ n: IntroNote) {
        if let i = notes.firstIndex(where: { $0.id == n.id }) {
            notes[i] = n
        } else {
            notes.insert(n, at: 0)
        }
    }

    func delete(_ n: IntroNote) {
        notes.removeAll { $0.id == n.id }
    }

    func toggleBookmark(id: UUID) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].isBookmarked.toggle()
    }

    func addVoiceNote(from url: URL) {
        upsert(.init(title: "Voice Note", content: "", audioURL: url))
    }

    // Persist
    private func save() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr  = try? JSONDecoder().decode([IntroNote].self, from: data) else { return }
        notes = arr
    }
}

// MARK: - Recorder (مايك بسيط)
final class IntroRecorder {
    private var recorder: AVAudioRecorder?
    private(set) var fileURL: URL?

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("rec_\(UUID().uuidString.prefix(6)).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let r = try AVAudioRecorder(url: url, settings: settings)
        r.record()
        recorder = r
        fileURL = url
    }

    func stop() {
        recorder?.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
