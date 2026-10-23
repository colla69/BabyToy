import AVFoundation
import BabyToyCore

/// Plays the synthesised tones on a fixed pool of 8 voices. The loudness is the fixed
/// in-app level, `Tones.masterLevel`, which is already in the samples. It never reads or
/// changes the system volume.
///
/// Sound is extra: if the engine cannot run, the toy goes on without it.
@MainActor
final class SoundPlayer {
  private static let voiceCount = 8

  private let engine = AVAudioEngine()
  private let players: [AVAudioPlayerNode]
  private let buffers: [Tone: AVAudioPCMBuffer]
  private var voices = VoicePool(size: voiceCount)
  private var configurationObserver: NSObjectProtocol?

  /// Returns `nil` if the tone buffers cannot be built. The toy then stays silent.
  init?() {
    guard let format = AVAudioFormat(standardFormatWithSampleRate: Tones.sampleRate, channels: 1)
    else {
      return nil
    }
    var buffers: [Tone: AVAudioPCMBuffer] = [:]
    for tone in Tones.allTones {
      guard let buffer = Self.makeBuffer(Tones.samples(for: tone), format: format) else {
        return nil
      }
      buffers[tone] = buffer
    }
    self.buffers = buffers
    players = (0..<Self.voiceCount).map { _ in AVAudioPlayerNode() }
    for player in players {
      engine.attach(player)
      engine.connect(player, to: engine.mainMixerNode, format: format)
    }
  }

  /// Starts the engine. A failed start gets one more try, then the toy stays silent.
  func start() {
    configurationObserver = NotificationCenter.default.addObserver(
      forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.restartAfterConfigurationChange()
      }
    }
    if !startEngine() {
      _ = startEngine()
    }
  }

  func play(keyCode: UInt16) {
    let tone = Tones.tone(for: KeyboardLayout.key(for: keyCode))
    guard engine.isRunning, let buffer = buffers[tone] else {
      return
    }
    let player = players[voices.nextIndex()]
    player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    if !player.isPlaying {
      player.play()
    }
  }

  func stop() {
    if let configurationObserver {
      NotificationCenter.default.removeObserver(configurationObserver)
    }
    configurationObserver = nil
    engine.stop()
  }

  /// The engine stops itself when the output changes, for example when headphones are
  /// plugged in. It gets one restart per change. If that fails, the toy stays silent.
  private func restartAfterConfigurationChange() {
    _ = startEngine()
  }

  private func startEngine() -> Bool {
    do {
      try engine.start()
    } catch {
      FileHandle.standardError.write(
        Data("BabyToy: sound engine did not start: \(error). The toy goes on silently.\n".utf8))
      return false
    }
    for player in players {
      player.play()
    }
    return true
  }

  private static func makeBuffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
    let frameCount = AVAudioFrameCount(samples.count)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
      let channel = buffer.floatChannelData?[0]
    else {
      return nil
    }
    buffer.frameLength = frameCount
    samples.withUnsafeBufferPointer { source in
      guard let base = source.baseAddress else {
        return
      }
      channel.update(from: base, count: samples.count)
    }
    return buffer
  }
}
