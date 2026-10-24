/// Hands out player indices round-robin, so a new sound takes the oldest voice.
public struct VoicePool: Sendable {
  public let size: Int
  private var next = 0

  public init(size: Int) {
    guard size > 0 else {
      fatalError("VoicePool needs at least one voice, got size \(size)")
    }
    self.size = size
  }

  public mutating func nextIndex() -> Int {
    let index = next
    next = (next + 1) % size
    return index
  }
}

/// Chooses the player for each tone. Key tones take turns on the first
/// `Tones.keyVoiceCount` voices, and a glide always has the last voice to itself, so a
/// moving pointer never cuts off a key's sound.
public struct ToneVoices: Sendable {
  public static let count = Tones.keyVoiceCount + 1

  private static let glideVoice = Tones.keyVoiceCount

  private var keyVoices = VoicePool(size: Tones.keyVoiceCount)

  public init() {}

  public mutating func voice(for tone: Tone) -> Int {
    switch tone {
    case .glide:
      Self.glideVoice
    case .note, .bell, .boom, .pluck:
      keyVoices.nextIndex()
    }
  }
}
