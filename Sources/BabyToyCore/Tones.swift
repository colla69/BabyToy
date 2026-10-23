import Foundation

/// The sound for a key group, for letters and clicks its pitch, and the soft note of a
/// moving pointer.
public enum Tone: Hashable, Sendable {
  /// A pentatonic note for a letter or a click. Step 0 is the lowest.
  case note(step: Int)
  /// A soft, short note for a moving pointer, at half the loudness of a key. Same steps as
  /// `note`.
  case glide(step: Int)
  /// A bell with two partials, for digits.
  case bell
  /// A soft low boom, for Space, Return and Delete.
  case boom
  /// A short high pluck, for every other key.
  case pluck
}

/// Synthesises every tone as mono Float samples. There are no audio files.
public enum Tones {
  public static let sampleRate = 44_100.0
  /// The loudest that all voices together may get.
  public static let masterLevel: Float = 0.25
  /// The peak of each key tone, so 8 voices at full overlap still stay under `masterLevel`.
  public static let peakLimit: Float = masterLevel / 8
  /// Keys and clicks share this many voices. The one voice left over plays glides only, so
  /// a moving pointer never cuts off a key's tone.
  public static let keyVoiceCount = 7

  /// Two octaves of the major pentatonic scale, so any mash of letters sounds pleasant.
  public static let noteSteps = 10

  /// Every tone a key or the pointer can ask for, so the player can build all buffers once
  /// at start.
  public static let allTones: [Tone] =
    (0..<noteSteps).map { Tone.note(step: $0) } + [
      .bell, .boom, .pluck,
    ] + (0..<noteSteps).map { Tone.glide(step: $0) }

  private static let pentatonicSemitones = [0, 2, 4, 7, 9]
  private static let lowestNote = 261.63  // C4
  /// The letters span about this part of the keyboard's width, Q at the left, P at the right.
  private static let letterSpan = 0.1...0.8

  public static func tone(for key: KeyInfo) -> Tone {
    switch key.group {
    case .letter: .note(step: noteStep(forX: key.x))
    case .digit: .bell
    case .bigKey: .boom
    case .other: .pluck
    }
  }

  /// The click note for a pointer at `x`, 0 at the left edge of the screen, 1 at the right.
  public static func tone(forPointerX x: Double) -> Tone {
    .note(step: pointerStep(forX: x))
  }

  /// The glide for a pointer at `x`. Its step is the click note's step at the same x.
  public static func glide(forPointerX x: Double) -> Tone {
    .glide(step: pointerStep(forX: x))
  }

  /// The fundamental frequency in hertz.
  public static func frequency(of tone: Tone) -> Double {
    switch tone {
    case .note(let step), .glide(let step):
      let octave = step / pentatonicSemitones.count
      let semitone = 12 * octave + pentatonicSemitones[step % pentatonicSemitones.count]
      return lowestNote * pow(2, Double(semitone) / 12)
    case .bell:
      return 880
    case .boom:
      return 110
    case .pluck:
      return 1320
    }
  }

  public static func samples(for tone: Tone) -> [Float] {
    let frequency = frequency(of: tone)
    switch tone {
    case .note:
      return synthesize(
        Voice(
          partials: [(1, 1), (2, 0.25), (3, 0.08)], duration: 0.45, attack: 0.008, decay: 0.15),
        frequency: frequency)
    case .glide:
      return synthesize(
        Voice(partials: [(1, 1), (2, 0.12)], duration: 0.25, attack: 0.02, decay: 0.08),
        frequency: frequency, peak: glidePeakLimit)
    case .bell:
      return synthesize(
        Voice(partials: [(1, 1), (2.76, 0.5)], duration: 0.9, attack: 0.003, decay: 0.3),
        frequency: frequency)
    case .boom:
      return synthesize(
        Voice(partials: [(1, 1), (2, 0.3)], duration: 0.5, attack: 0.01, decay: 0.12),
        frequency: frequency)
    case .pluck:
      return synthesize(
        Voice(partials: [(1, 1), (2, 0.3)], duration: 0.15, attack: 0.002, decay: 0.04),
        frequency: frequency)
    }
  }

  /// The pointer's notes span the whole screen width.
  private static func pointerStep(forX x: Double) -> Int {
    min(max(Int(x * Double(noteSteps)), 0), noteSteps - 1)
  }

  private static func noteStep(forX x: Double) -> Int {
    let position = (x - letterSpan.lowerBound) / (letterSpan.upperBound - letterSpan.lowerBound)
    return min(max(Int(position * Double(noteSteps)), 0), noteSteps - 1)
  }

  /// The shape of one sound: its partials as (frequency ratio, amplitude) and its envelope
  /// in seconds.
  private struct Voice {
    let partials: [(ratio: Double, amplitude: Double)]
    let duration: Double
    let attack: Double
    let decay: Double
  }

  /// The last 10 ms fade to exactly zero, so a tone that ends never clicks.
  private static let releaseSeconds = 0.01
  /// Half a key's peak, so a glide stays under the keys it plays along with.
  private static let glidePeakLimit = peakLimit / 2

  /// Scales the samples to a little below `peak`, so Float rounding cannot push a sample
  /// over it.
  private static func synthesize(_ voice: Voice, frequency: Double, peak limit: Float = peakLimit)
    -> [Float]
  {
    let count = Int(voice.duration * sampleRate)
    let releaseCount = Int(releaseSeconds * sampleRate)
    var samples = (0..<count).map { index -> Double in
      let time = Double(index) / sampleRate
      let wave = voice.partials.reduce(0) { sum, partial in
        sum + partial.amplitude * sin(2 * .pi * frequency * partial.ratio * time)
      }
      return wave * envelope(voice, time: time, index: index, count: count, release: releaseCount)
    }
    let peak = samples.map(abs).max() ?? 0
    guard peak > 0 else {
      return samples.map(Float.init)
    }
    let gain = Double(limit * 0.95) / peak
    samples = samples.map { $0 * gain }
    return samples.map(Float.init)
  }

  private static func envelope(_ voice: Voice, time: Double, index: Int, count: Int, release: Int)
    -> Double
  {
    let rise = min(time / voice.attack, 1)
    let fall = exp(-max(time - voice.attack, 0) / voice.decay)
    let remaining = count - 1 - index
    let tail = remaining < release ? Double(remaining) / Double(release) : 1
    return rise * fall * tail
  }
}
