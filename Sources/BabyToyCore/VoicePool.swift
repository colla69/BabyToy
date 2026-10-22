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
