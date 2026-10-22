import Testing

@testable import BabyToyCore

private let allKeys = (UInt16(0)..<128).map { KeyboardLayout.key(for: $0) }

private func peak(_ samples: [Float]) -> Float {
  samples.map(abs).max() ?? 0
}

@Suite("Tones")
struct TonesTests {
  @Test("The master level is 0.25")
  func masterLevelIsOptionA() {
    #expect(Tones.masterLevel == 0.25)
  }

  @Test("Every tone peaks at most at masterLevel / 8, and is clearly audible")
  func peakIsBounded() {
    #expect(!Tones.allTones.isEmpty)
    for tone in Tones.allTones {
      let samples = Tones.samples(for: tone)

      #expect(peak(samples) <= Tones.masterLevel / 8, "\(tone)")
      #expect(peak(samples) > Tones.masterLevel / 16, "\(tone)")
    }
  }

  @Test("Every tone starts and ends at about zero, so it does not click")
  func startsAndEndsAtZero() {
    for tone in Tones.allTones {
      let samples = Tones.samples(for: tone)

      #expect(abs(samples.first ?? 1) < 1e-4, "\(tone)")
      #expect(abs(samples.last ?? 1) < 1e-4, "\(tone)")
    }
  }

  @Test("Letter pitch rises from the left of the keyboard to the right")
  func letterPitchRisesLeftToRight() {
    let letters = allKeys.filter { $0.group == .letter }.sorted { $0.x < $1.x }
    let frequencies = letters.map { Tones.frequency(of: Tones.tone(for: $0)) }

    #expect(letters.count == 26)
    #expect(zip(frequencies, frequencies.dropFirst()).allSatisfy { $0 <= $1 })
    #expect((frequencies.first ?? 0) < (frequencies.last ?? 0))
  }

  @Test("Each key group gets its own kind of sound")
  func soundByGroup() {
    let q = KeyboardLayout.key(for: 12)

    guard case .note = Tones.tone(for: q) else {
      Issue.record("Q got \(Tones.tone(for: q))")
      return
    }
    #expect(Tones.tone(for: KeyboardLayout.key(for: 18)) == .bell)
    #expect(Tones.tone(for: KeyboardLayout.key(for: 49)) == .boom)
    #expect(Tones.tone(for: KeyboardLayout.key(for: 56)) == .pluck)
  }

  @Test("Every key's tone is in the set that is built once at start")
  func allTonesCoverEveryKey() {
    let built = Set(Tones.allTones)

    #expect(allKeys.allSatisfy { built.contains(Tones.tone(for: $0)) })
  }
}

@Suite("Voice pool")
struct VoicePoolTests {
  @Test("200 requests in one burst use only indices 0 to 7, in turn")
  func burstStaysInPool() {
    var pool = VoicePool(size: 8)

    let indices = (0..<200).map { _ in pool.nextIndex() }

    #expect(indices.allSatisfy { (0...7).contains($0) })
    #expect(Array(indices.prefix(8)) == Array(0...7))
  }

  @Test("The 9th request reuses index 0")
  func ninthRequestReusesFirst() {
    var pool = VoicePool(size: 8)

    let indices = (0..<9).map { _ in pool.nextIndex() }

    #expect(indices[8] == 0)
  }
}
