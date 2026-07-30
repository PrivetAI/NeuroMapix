import Foundation
import AVFoundation
import UIKit

/// Local-only feedback: a synthesized tone through AVAudioEngine (no audio files,
/// no network) plus the system haptic generators.
final class Feedback {

    static let shared = Feedback()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var prepared = false
    private var buffers: [String: AVAudioPCMBuffer] = [:]

    var soundEnabled = false
    var hapticsEnabled = true

    private init() {}

    private func prepare() {
        guard !prepared else { return }
        prepared = true
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        guard let format else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.22
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            player.play()
        } catch {
            prepared = false
        }
    }

    private func buffer(frequency: Double, duration: Double, key: String) -> AVAudioPCMBuffer? {
        if let cached = buffers[key] { return cached }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else { return nil }
        let frames = AVAudioFrameCount(44_100 * duration)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        for i in 0..<Int(frames) {
            let t = Double(i) / 44_100.0
            let envelope = exp(-4.0 * t / duration)
            channel[i] = Float(sin(2.0 * Double.pi * frequency * t) * envelope * 0.6)
        }
        buffers[key] = buffer
        return buffer
    }

    private func tone(_ frequency: Double, _ duration: Double, _ key: String) {
        guard soundEnabled else { return }
        prepare()
        guard prepared, engine.isRunning, let buffer = buffer(frequency: frequency, duration: duration, key: key) else { return }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    func tap() {
        tone(660, 0.06, "tap")
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func confirm() {
        tone(880, 0.14, "confirm")
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func success() {
        tone(1_040, 0.22, "success")
        guard hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func failure() {
        tone(320, 0.24, "failure")
        guard hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
