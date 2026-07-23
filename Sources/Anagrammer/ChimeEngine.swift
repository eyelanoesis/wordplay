import AVFoundation
import AnagramEngine

/// Each dimension has a note (C-major pentatonic-ish spread). Traveling the
/// web plays your journey; a found path plays as a little melody. Pure
/// synthesis — sine voices with exponential decay, no audio assets.
final class ChimeEngine: @unchecked Sendable {
    static let shared = ChimeEngine()

    var muted = false
    var voiceEnabled = false
    private let synthesizer = AVSpeechSynthesizer()

    /// Pronounce a word aloud, softly and unhurried. Honors the voice toggle.
    func speak(_ word: String) {
        guard voiceEnabled else { return }
        speakNow(word)
    }

    /// Pronounce a word immediately — for places where speaking IS the user's
    /// explicit action (e.g. tapping a minimal pair to hear the contrast).
    /// Bypasses the ambient voice toggle but still honors mute.
    func speakNow(_ word: String) {
        guard !muted else { return }
        let utterance = AVSpeechUtterance(string: word)
        utterance.rate = 0.42
        utterance.volume = 0.8
        utterance.pitchMultiplier = 0.95
        synthesizer.speak(utterance)
    }

    private struct Voice { var freq: Double; var phase: Double; var amp: Double }

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var voices: [Voice] = []
    private var started = false
    private let sampleRate = 44100.0
    private let decayPerSample = 0.99988   // ~1.1 s ring-out

    private init() {}

    func play(_ relation: ConnectionWeb.Relation?) {
        let freq: Double
        switch relation {
        case nil: freq = 523.25              // C5 — igniting a seed
        case .anagram: freq = 261.63         // C4
        case .oneLetter: freq = 293.66       // D4
        case .homophone: freq = 329.63       // E4
        case .rhyme: freq = 392.00           // G4
        case .fusion: freq = 440.00          // A4
        case .hidden: freq = 587.33          // D5
        case .audible: freq = 659.26         // E5
        case .reversal: freq = 783.99        // G5
        case .association: freq = 880.00     // A5
        }
        play(rawFrequency: freq)
    }

    /// The infection interval: a low, detuned minor second — wrong on purpose.
    func playInfection() {
        play(rawFrequency: 185.00, amplitude: 0.10)
        play(rawFrequency: 196.60, amplitude: 0.10)
    }

    func play(rawFrequency freq: Double, amplitude: Double = 0.16) {
        guard !muted else { return }
        startIfNeeded()
        lock.lock()
        voices.append(Voice(freq: freq, phase: 0, amp: amplitude))
        if voices.count > 12 { voices.removeFirst(voices.count - 12) }
        lock.unlock()
    }

    private func startIfNeeded() {
        guard !started else { return }
        started = true
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            self.lock.lock()
            var live = self.voices
            for frame in 0..<Int(frameCount) {
                var sample: Double = 0
                for i in live.indices {
                    sample += sin(live[i].phase) * live[i].amp
                    live[i].phase += 2 * .pi * live[i].freq / self.sampleRate
                    live[i].amp *= self.decayPerSample
                }
                let value = Float(sample)
                for buffer in buffers {
                    guard let data = buffer.mData else { continue }
                    data.assumingMemoryBound(to: Float.self)[frame] = value
                }
            }
            self.voices = live.filter { $0.amp > 0.0008 }
            self.lock.unlock()
            return noErr
        }
        engine.attach(node)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.9
        try? engine.start()
    }
}
