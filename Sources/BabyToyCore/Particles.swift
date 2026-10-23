import Foundation

/// How many particles each reaction gets. Above `Particles.fullDetailLimit` live reactions,
/// each gets half, so a frame at the cap of 200 stays inside 16 ms.
enum Detail: Sendable, Equatable {
  case full
  case half
}

/// One thing to draw for a reaction. Offsets and sizes are in units of u, the short side
/// of the screen, so a smaller picture is a scaled copy.
struct Particle: Sendable, Equatable {
  enum Kind: Sendable, Equatable {
    /// A radial gradient, brightest at the centre.
    case glowDot
    case filledDot
    /// A stroked ellipse. `heightRatio` is its height over its width.
    case ring(heightRatio: Double, lineWidth: Double)
  }

  enum Blend: Sendable, Equatable {
    /// Light adds up, so dense fire and sparks turn white.
    case additive
    case normal
  }

  /// From the reaction's place. Positive x is right, positive y is down.
  let x: Double
  let y: Double
  let radius: Double
  let color: RGBColor
  let alpha: Double
  let kind: Kind
  let blend: Blend

  fileprivate func scaled(by factor: Double) -> Particle {
    let scaledKind: Kind =
      switch kind {
      case .glowDot, .filledDot: kind
      case .ring(let heightRatio, let lineWidth):
        .ring(heightRatio: heightRatio, lineWidth: lineWidth * factor)
      }
    return Particle(
      x: x * factor, y: y * factor, radius: radius * factor, color: color, alpha: alpha,
      kind: scaledKind, blend: blend)
  }
}

/// The particles of a reaction, as pure functions of the reaction, the time and the detail.
/// Each reaction draws its random details from its own seed, in slot order, so the half set
/// and the trail set are the first slots of the full set and nothing reshuffles when the
/// detail changes.
enum Particles {
  static let fullDetailLimit = 100

  /// A trail is a small copy of the first slots of a burst.
  private static let trailScale = 0.6

  static func detail(forLiveCount count: Int) -> Detail {
    count <= fullDetailLimit ? .full : .half
  }

  static func particles(for reaction: Reaction, at time: Double, detail: Detail) -> [Particle] {
    let age = max(time - reaction.spawnTime, 0)
    var random = SeededRandom(seed: reaction.seed)
    let full: [Particle] =
      switch reaction.element {
      case .fire: Fire.particles(age: age, random: &random)
      case .water: Water.particles(age: age, random: &random)
      case .explosion: Explosion.particles(age: age, random: &random)
      case .drop: Drop.particles(age: age, seed: reaction.seed, random: &random)
      }
    switch (reaction.strength, detail) {
    case (.burst, .full):
      return full
    case (.burst, .half):
      return Array(full.prefix(full.count / 2))
    case (.trail, _):
      let count = trailCount(reaction.element)
      return full.prefix(count).map { $0.scaled(by: trailScale) }
    }
  }

  /// The glow and flash that only the newest reactions get. Empty once they are over.
  static func extras(for reaction: Reaction, at time: Double) -> [Particle] {
    guard reaction.strength == .burst else {
      return []
    }
    let age = max(time - reaction.spawnTime, 0)
    switch reaction.element {
    case .fire: return Fire.extras(age: age)
    case .explosion: return Explosion.extras(age: age)
    case .water, .drop: return []
    }
  }

  private static func trailCount(_ element: Element) -> Int {
    switch element {
    case .fire: 3
    case .water: 3
    case .explosion: 4
    case .drop: 2
    }
  }
}

// MARK: - Fire

private enum Fire {
  static let count = 12
  static let yellow = RGBColor(red: 1.0, green: 0.85, blue: 0.4)
  static let orange = RGBColor(red: 1.0, green: 0.45, blue: 0.08)
  static let darkRed = RGBColor(red: 0.6, green: 0.08, blue: 0.02)
  static let glowDuration = 0.6

  /// Each particle starts after a short delay, rises a little faster over time and sways.
  static func particles(age: Double, random: inout SeededRandom) -> [Particle] {
    (0..<count).map { _ in
      let delay = Double.random(in: 0...0.3, using: &random)
      let speed = Double.random(in: 0.12...0.22, using: &random)
      let swayHertz = Double.random(in: 1.5...3, using: &random)
      let swayPhase = Double.random(in: 0...(2 * .pi), using: &random)
      let startRadius = Double.random(in: 0.010...0.016, using: &random)
      let elapsed = age - delay
      guard elapsed >= 0 else {
        return Particle(
          x: 0, y: 0, radius: startRadius, color: yellow, alpha: 0, kind: .glowDot,
          blend: .additive)
      }
      let progress = min(elapsed / (Scene.lifetime - delay), 1)
      let acceleration = 0.06
      return Particle(
        x: 0.012 * sin(2 * .pi * swayHertz * elapsed + swayPhase),
        y: -(speed * elapsed + 0.5 * acceleration * elapsed * elapsed),
        radius: startRadius * (1 - 0.7 * progress),
        color: colorRamp(yellow, orange, darkRed, progress),
        alpha: fadeOut(progress, from: 0.6),
        kind: .glowDot, blend: .additive)
    }
  }

  static func extras(age: Double) -> [Particle] {
    guard age < glowDuration else {
      return []
    }
    return [
      Particle(
        x: 0, y: 0, radius: 0.05, color: orange, alpha: 0.5 * (1 - age / glowDuration),
        kind: .glowDot, blend: .additive)
    ]
  }
}

// MARK: - Water

private enum Water {
  /// A ring, then four droplets, then the second ring and the other four droplets. The
  /// half set is then one ring and four droplets, and a trail one ring and two droplets.
  static let slots: [Slot] = [
    .ring(0), .droplet, .droplet, .droplet, .droplet, .ring(1), .droplet, .droplet, .droplet,
    .droplet,
  ]
  static let ringColor = RGBColor(red: 0.6, green: 0.92, blue: 1.0)
  static let lightCyan = RGBColor(red: 0.55, green: 0.88, blue: 1.0)
  static let blue = RGBColor(red: 0.2, green: 0.5, blue: 1.0)
  static let gravity = 0.9

  enum Slot {
    case ring(Int)
    case droplet
  }

  static func particles(age: Double, random: inout SeededRandom) -> [Particle] {
    slots.map { slot in
      switch slot {
      case .ring(let index): ring(index, age: age)
      case .droplet: droplet(age: age, random: &random)
      }
    }
  }

  /// A flat ripple that grows fast, then slows, and thins as it fades.
  private static func ring(_ index: Int, age: Double) -> Particle {
    let start = 0.2 * Double(index)
    let progress = (age - start) / (Scene.lifetime - start)
    guard progress >= 0 else {
      return Particle(
        x: 0, y: 0, radius: 0.005, color: ringColor, alpha: 0,
        kind: .ring(heightRatio: 0.45, lineWidth: 0.006), blend: .normal)
    }
    let clamped = min(progress, 1)
    return Particle(
      x: 0, y: 0, radius: max(0.09 * easeOut(clamped), 0.005), color: ringColor,
      alpha: 0.9 * (1 - clamped),
      kind: .ring(heightRatio: 0.45, lineWidth: 0.006 * (1 - clamped) + 0.001), blend: .normal)
  }

  /// Thrown up, then falling under gravity.
  private static func droplet(age: Double, random: inout SeededRandom) -> Particle {
    let sideways = Double.random(in: -0.10...0.10, using: &random)
    let upwards = Double.random(in: 0.15...0.30, using: &random)
    let radius = Double.random(in: 0.006...0.009, using: &random)
    let tint = Double.random(in: 0...1, using: &random)
    return Particle(
      x: sideways * age, y: -upwards * age + 0.5 * gravity * age * age, radius: radius,
      color: mix(lightCyan, blue, tint), alpha: fadeOut(age / Scene.lifetime, from: 0.5),
      kind: .glowDot, blend: .normal)
  }
}

// MARK: - Explosion

private enum Explosion {
  static let count = 16
  static let white = RGBColor(red: 1, green: 1, blue: 1)
  static let gold = RGBColor(red: 1.0, green: 0.8, blue: 0.25)
  static let magenta = RGBColor(red: 0.95, green: 0.25, blue: 0.75)
  static let flashColor = RGBColor(red: 1, green: 1, blue: 0.9)
  static let drag = 3.0
  static let gravity = 0.15
  static let flashDuration = 0.15
  static let shockGrowth = 0.4
  static let shockDuration = 0.5

  /// Spark k flies at (7k mod 16) × 22.5°, so the first 8 sparks already point in every
  /// direction and the half set still spreads all round.
  static func particles(age: Double, random: inout SeededRandom) -> [Particle] {
    let decay = (1 - exp(-drag * age)) / drag
    let progress = min(age / Scene.lifetime, 1)
    return (0..<count).map { index in
      let jitter = Double.random(in: -8...8, using: &random)
      let speed = Double.random(in: 0.35...0.55, using: &random)
      let radius = Double.random(in: 0.006...0.009, using: &random)
      let degrees = Double(7 * index % count) * 22.5 + jitter
      let angle = degrees * .pi / 180
      let distance = speed * decay
      return Particle(
        x: distance * cos(angle), y: -distance * sin(angle) + 0.5 * gravity * age * age,
        radius: radius, color: colorRamp(white, gold, magenta, progress),
        alpha: fadeOut(progress, from: 0.5), kind: .glowDot, blend: .additive)
    }
  }

  /// A short flash at the centre, and a shock ring that grows and fades.
  static func extras(age: Double) -> [Particle] {
    var extras: [Particle] = []
    if age < flashDuration {
      let progress = age / flashDuration
      extras.append(
        Particle(
          x: 0, y: 0, radius: 0.05, color: flashColor, alpha: 1 - progress * progress,
          kind: .glowDot, blend: .additive))
    }
    if age < shockDuration {
      extras.append(
        Particle(
          x: 0, y: 0, radius: max(0.10 * easeOut(min(age / shockGrowth, 1)), 0.005),
          color: white, alpha: 0.8 * (1 - age / shockDuration),
          kind: .ring(heightRatio: 1, lineWidth: 0.004), blend: .additive))
    }
    return extras
  }
}

// MARK: - Drop

private enum Drop {
  /// The drop (or its blot), a ring, two crown droplets, the second ring, three more crown
  /// droplets. The half set is then the drop, one ring and two crown droplets.
  static let slots: [Slot] = [
    .dropOrBlot, .ring(0), .crown, .crown, .ring(1), .crown, .crown, .crown,
  ]
  static let colors = [
    RGBColor(red: 0.45, green: 0.90, blue: 0.35),
    RGBColor(red: 0.70, green: 0.45, blue: 1.00),
    RGBColor(red: 1.00, green: 0.45, blue: 0.80),
  ]
  static let startHeight = 0.12
  static let gravity = 2.67
  /// About 0.3 s.
  static let landingTime = (2 * startHeight / gravity).squareRoot()
  static let dropRadius = 0.015
  static let blotRadius = 0.035
  static let blotGrownAt = 0.6
  static let ringRadii = [0.06, 0.09]
  static let ringDelay = 0.15
  static let crownDuration = 0.3

  enum Slot {
    case dropOrBlot
    case ring(Int)
    case crown
  }

  static func particles(age: Double, seed: UInt64, random: inout SeededRandom) -> [Particle] {
    let color = colors[Int(seed % UInt64(colors.count))]
    return slots.map { slot in
      switch slot {
      case .dropOrBlot: dropOrBlot(age: age, color: color)
      case .ring(let index): ring(index, age: age, color: color)
      case .crown: crown(age: age, color: color, random: &random)
      }
    }
  }

  private static func dropOrBlot(age: Double, color: RGBColor) -> Particle {
    guard age >= landingTime else {
      return Particle(
        x: 0, y: -startHeight + 0.5 * gravity * age * age, radius: dropRadius, color: color,
        alpha: 1, kind: .filledDot, blend: .normal)
    }
    let growth = easeOut(min((age - landingTime) / (blotGrownAt - landingTime), 1))
    return Particle(
      x: 0, y: 0, radius: dropRadius + (blotRadius - dropRadius) * growth, color: color,
      alpha: fadeOut(age / Scene.lifetime, from: 0.5), kind: .glowDot, blend: .normal)
  }

  private static func ring(_ index: Int, age: Double, color: RGBColor) -> Particle {
    let start = landingTime + ringDelay * Double(index)
    let progress = (age - start) / (Scene.lifetime - start)
    guard progress >= 0 else {
      return Particle(
        x: 0, y: 0, radius: dropRadius, color: color, alpha: 0,
        kind: .ring(heightRatio: 1, lineWidth: 0.005), blend: .normal)
    }
    let clamped = min(progress, 1)
    let radius = dropRadius + (ringRadii[index] - dropRadius) * easeOut(clamped)
    return Particle(
      x: 0, y: 0, radius: radius, color: color, alpha: 0.9 * (1 - clamped),
      kind: .ring(heightRatio: 1, lineWidth: 0.005 * (1 - clamped) + 0.001), blend: .normal)
  }

  /// Pops up from the landing place and falls back.
  private static func crown(age: Double, color: RGBColor, random: inout SeededRandom)
    -> Particle
  {
    let sideways = Double.random(in: -1...1, using: &random)
    let height = Double.random(in: 0.02...0.04, using: &random)
    let progress = (age - landingTime) / crownDuration
    guard (0...1).contains(progress) else {
      return Particle(
        x: 0, y: 0, radius: 0.005, color: color, alpha: 0, kind: .filledDot, blend: .normal)
    }
    return Particle(
      x: 0.035 * sideways * progress, y: -4 * height * progress * (1 - progress), radius: 0.005,
      color: color, alpha: 1, kind: .filledDot, blend: .normal)
  }
}

// MARK: - Shared curves

/// Fast at first, then slow, from 0 to 1.
private func easeOut(_ progress: Double) -> Double {
  let remaining = 1 - progress
  return 1 - remaining * remaining * remaining
}

/// 1 until `start`, then down to exactly 0 at 1.
private func fadeOut(_ progress: Double, from start: Double) -> Double {
  guard progress > start else {
    return 1
  }
  return max(1 - (progress - start) / (1 - start), 0)
}

private func mix(_ from: RGBColor, _ to: RGBColor, _ amount: Double) -> RGBColor {
  RGBColor(
    red: from.red + (to.red - from.red) * amount,
    green: from.green + (to.green - from.green) * amount,
    blue: from.blue + (to.blue - from.blue) * amount)
}

/// `start` at 0, `middle` at 0.4, `end` at 1.
private func colorRamp(_ start: RGBColor, _ middle: RGBColor, _ end: RGBColor, _ progress: Double)
  -> RGBColor
{
  let middlePoint = 0.4
  if progress < middlePoint {
    return mix(start, middle, progress / middlePoint)
  }
  return mix(middle, end, (progress - middlePoint) / (1 - middlePoint))
}
