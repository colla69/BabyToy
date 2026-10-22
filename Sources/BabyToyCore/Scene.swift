public struct RGBColor: Sendable, Equatable {
  public let red: Double
  public let green: Double
  public let blue: Double

  public init(red: Double, green: Double, blue: Double) {
    self.red = red
    self.green = green
    self.blue = blue
  }
}

public enum ReactionShape: Sendable, Equatable {
  case circle
  case star
  case roundedSquare
  case ring
}

/// The visual answer to one key press.
public struct Reaction: Sendable, Equatable {
  public let keyCode: UInt16
  /// 0 is the left edge of the screen, 1 the right edge.
  public let x: Double
  /// 0 is the top edge of the screen, 1 the bottom edge.
  public let y: Double
  public let shape: ReactionShape
  public let color: RGBColor
  public let label: Character?
  /// Seconds, on the same clock as the times passed to `Scene`.
  public let spawnTime: Double

  public init(
    keyCode: UInt16, x: Double, y: Double, shape: ReactionShape, color: RGBColor,
    label: Character?, spawnTime: Double
  ) {
    self.keyCode = keyCode
    self.x = x
    self.y = y
    self.shape = shape
    self.color = color
    self.label = label
    self.spawnTime = spawnTime
  }

  /// How far through its life the reaction is: 0 at spawn, 1 at the end.
  private func progress(at time: Double) -> Double {
    min(max((time - spawnTime) / Scene.lifetime, 0), 1)
  }

  /// Size relative to the base size. It grows fast at first, then slows down.
  public func scale(at time: Double) -> Double {
    let remaining = 1 - progress(at: time)
    return 0.5 + 0.8 * (1 - remaining * remaining * remaining)
  }

  /// 1 is fully visible, 0 is gone. It stays bright for the first third of its life, then
  /// fades out smoothly.
  public func opacity(at time: Double) -> Double {
    let fadeStart = 0.3
    let fade = min(max((progress(at: time) - fadeStart) / (1 - fadeStart), 0), 1)
    return 1 - fade * fade * (3 - 2 * fade)
  }
}

/// Everything on screen. A value type, so a copy can go to a render queue.
public struct Scene: Sendable {
  public static let maxReactions = 200
  /// Seconds a reaction lives.
  public static let lifetime = 1.5

  /// How far a reaction may land from its key, as a fraction of the screen.
  private static let jitter = 0.03

  /// Bright colours that read well on the dark background.
  private static let palette: [RGBColor] = [
    RGBColor(red: 1.00, green: 0.36, blue: 0.36),
    RGBColor(red: 1.00, green: 0.66, blue: 0.20),
    RGBColor(red: 1.00, green: 0.90, blue: 0.25),
    RGBColor(red: 0.45, green: 0.90, blue: 0.35),
    RGBColor(red: 0.25, green: 0.85, blue: 0.85),
    RGBColor(red: 0.35, green: 0.60, blue: 1.00),
    RGBColor(red: 0.70, green: 0.45, blue: 1.00),
    RGBColor(red: 1.00, green: 0.45, blue: 0.80),
  ]

  /// Oldest first.
  public private(set) var reactions: [Reaction] = []
  private var random: SeededRandom

  public init(seed: UInt64 = 1) {
    random = SeededRandom(seed: seed)
  }

  public mutating func press(keyCode: UInt16, at time: Double) {
    let key = KeyboardLayout.key(for: keyCode)
    let reaction = Reaction(
      keyCode: keyCode,
      x: jittered(key.x),
      y: jittered(key.y),
      shape: Self.shape(for: key.group),
      color: Self.palette.randomElement(using: &random) ?? Self.palette[0],
      label: key.label,
      spawnTime: time)
    reactions.append(reaction)
    if reactions.count > Self.maxReactions {
      reactions.removeFirst(reactions.count - Self.maxReactions)
    }
  }

  /// Removes the reactions that are at or past the end of their lifetime.
  public mutating func prune(at time: Double) {
    reactions.removeAll { time - $0.spawnTime >= Self.lifetime }
  }

  private mutating func jittered(_ value: Double) -> Double {
    let offset = Double.random(in: -Self.jitter...Self.jitter, using: &random)
    return min(max(value + offset, 0), 1)
  }

  private static func shape(for group: KeyGroup) -> ReactionShape {
    switch group {
    case .letter: .circle
    case .digit: .star
    case .bigKey: .roundedSquare
    case .other: .ring
    }
  }
}
