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

/// How big a reaction is: a key press or a click makes a burst, a moving pointer a trail.
public enum ReactionStrength: Sendable, Equatable {
  case burst
  case trail
}

/// The visual answer to one key press, one click or one step of a moving pointer.
public struct Reaction: Sendable, Equatable {
  /// 0 is the left edge of the screen, 1 the right edge.
  public let x: Double
  /// 0 is the top edge of the screen, 1 the bottom edge.
  public let y: Double
  public let element: Element
  public let strength: ReactionStrength
  /// Sets the details that differ between reactions of one element, such as the particle
  /// directions and the colour of a drop.
  public let seed: UInt64
  /// Seconds, on the same clock as the times passed to `Scene`.
  public let spawnTime: Double

  public init(
    x: Double, y: Double, element: Element, strength: ReactionStrength, seed: UInt64,
    spawnTime: Double
  ) {
    self.x = x
    self.y = y
    self.element = element
    self.strength = strength
    self.seed = seed
    self.spawnTime = spawnTime
  }
}

/// Everything on screen. A value type, so a copy can go to a render queue.
public struct Scene: Sendable {
  public static let maxReactions = 200
  /// Seconds a reaction lives.
  public static let lifetime = 1.5

  /// How far a reaction may land from its key, as a fraction of the screen.
  private static let jitter = 0.03

  /// Oldest first.
  public private(set) var reactions: [Reaction] = []
  private var random: SeededRandom

  public init(seed: UInt64 = 1) {
    random = SeededRandom(seed: seed)
  }

  /// A key press. The effect comes from the key's place in the key map, and the reaction
  /// lands within a little jitter of that place.
  public mutating func press(keyCode: UInt16, at time: Double) {
    let key = KeyboardLayout.key(for: keyCode)
    let x = jittered(key.x)
    let y = jittered(key.y)
    add(x: x, y: y, element: Element.forKey(key), strength: .burst, at: time)
  }

  /// A click at the pointer's place, given as 0…1 with y = 0 at the top.
  public mutating func burst(x: Double, y: Double, at time: Double) {
    add(x: x, y: y, element: Element.at(x: x, y: y), strength: .burst, at: time)
  }

  /// One step of a moving pointer, at its place.
  public mutating func trail(x: Double, y: Double, at time: Double) {
    add(x: x, y: y, element: Element.at(x: x, y: y), strength: .trail, at: time)
  }

  /// Removes the reactions that are at or past the end of their lifetime.
  public mutating func prune(at time: Double) {
    reactions.removeAll { time - $0.spawnTime >= Self.lifetime }
  }

  private mutating func add(
    x: Double, y: Double, element: Element, strength: ReactionStrength, at time: Double
  ) {
    let reaction = Reaction(
      x: x, y: y, element: element, strength: strength, seed: random.next(), spawnTime: time)
    reactions.append(reaction)
    if reactions.count > Self.maxReactions {
      reactions.removeFirst(reactions.count - Self.maxReactions)
    }
  }

  private mutating func jittered(_ value: Double) -> Double {
    let offset = Double.random(in: -Self.jitter...Self.jitter, using: &random)
    return min(max(value + offset, 0), 1)
  }
}
