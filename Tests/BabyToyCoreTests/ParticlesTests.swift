import Testing

@testable import BabyToyCore

private func reaction(
  _ element: Element, strength: ReactionStrength = .burst, seed: UInt64 = 42
) -> Reaction {
  Reaction(x: 0.5, y: 0.5, element: element, strength: strength, seed: seed, spawnTime: 0)
}

private func visible(_ particles: [Particle]) -> [Particle] {
  particles.filter { $0.alpha > 0 }
}

/// Height above the place, in u. Particle offsets point down, so height is -y.
private func meanHeight(_ particles: [Particle]) -> Double {
  particles.map { -$0.y }.reduce(0, +) / Double(particles.count)
}

private func distance(_ particle: Particle) -> Double {
  (particle.x * particle.x + particle.y * particle.y).squareRoot()
}

private func meanDistance(_ particles: [Particle]) -> Double {
  particles.map(distance).reduce(0, +) / Double(particles.count)
}

private func isRing(_ particle: Particle) -> Bool {
  if case .ring = particle.kind { true } else { false }
}

@Suite("Particles, every effect")
struct ParticlesCommonTests {
  @Test("Equal inputs give equal particles", arguments: Element.allCases)
  func deterministic(element: Element) {
    let first = Particles.particles(for: reaction(element), at: 0.4, detail: .full)
    let second = Particles.particles(for: reaction(element), at: 0.4, detail: .full)

    #expect(first == second)
    #expect(!first.isEmpty)
  }

  @Test("Every alpha is 0 at the lifetime", arguments: Element.allCases)
  func goneAtLifetime(element: Element) {
    let particles = Particles.particles(for: reaction(element), at: Scene.lifetime, detail: .full)
    let extras = Particles.extras(for: reaction(element), at: Scene.lifetime)

    #expect(!particles.isEmpty)
    #expect((particles + extras).allSatisfy { $0.alpha == 0 })
  }

  @Test("The half set is the first half of the full set", arguments: Element.allCases)
  func halfIsPrefixOfFull(element: Element) {
    for time in [0.05, 0.4, 1.0] {
      let full = Particles.particles(for: reaction(element), at: time, detail: .full)
      let half = Particles.particles(for: reaction(element), at: time, detail: .half)

      #expect(half == Array(full.prefix(full.count / 2)), "\(time)")
    }
  }

  @Test("A trail has fewer and smaller particles than a burst", arguments: Element.allCases)
  func trailIsSmaller(element: Element) {
    let burst = Particles.particles(for: reaction(element), at: 0.5, detail: .full)
    let trail = Particles.particles(
      for: reaction(element, strength: .trail), at: 0.5, detail: .full)
    let burstRadius = visible(burst).map(\.radius).max() ?? 0
    let trailRadius = visible(trail).map(\.radius).max() ?? 0

    #expect(trail.count < burst.count)
    #expect(trailRadius > 0 && trailRadius < burstRadius)
  }

  @Test("A trail has no extras", arguments: Element.allCases)
  func trailHasNoExtras(element: Element) {
    #expect(Particles.extras(for: reaction(element, strength: .trail), at: 0.05).isEmpty)
  }

  @Test("The detail is full at 100 live reactions and half at 101")
  func detailRule() {
    #expect(Particles.detail(forLiveCount: 100) == .full)
    #expect(Particles.detail(forLiveCount: 101) == .half)
  }
}

@Suite("Particles, each effect")
struct ParticlesEffectTests {
  @Test("Fire rises: the mean height at 1.0 s is above the mean at 0.2 s")
  func fireRises() {
    let early = Particles.particles(for: reaction(.fire), at: 0.2, detail: .full)
    let late = Particles.particles(for: reaction(.fire), at: 1.0, detail: .full)

    #expect(meanHeight(late) > meanHeight(early))
  }

  @Test("Fire's glow exists before 0.6 s and not after")
  func fireGlow() {
    #expect(!visible(Particles.extras(for: reaction(.fire), at: 0.3)).isEmpty)
    #expect(visible(Particles.extras(for: reaction(.fire), at: 0.7)).isEmpty)
  }

  @Test("Water's droplets fall: their mean height at 1.2 s is below the mean at 0.3 s")
  func waterDropletsFall() {
    let droplets = { (time: Double) in
      Particles.particles(for: reaction(.water), at: time, detail: .full).filter { !isRing($0) }
    }

    #expect(meanHeight(droplets(1.2)) < meanHeight(droplets(0.3)))
  }

  @Test("Water and drop have no extras", arguments: [Element.water, .drop])
  func noExtras(element: Element) {
    for time in [0.0, 0.05, 0.3, 0.7] {
      #expect(Particles.extras(for: reaction(element), at: time).isEmpty)
    }
  }

  @Test("An explosion spreads: the mean distance at 0.4 s is over twice that at 0.1 s")
  func explosionSpreads() {
    let early = Particles.particles(for: reaction(.explosion), at: 0.1, detail: .full)
    let late = Particles.particles(for: reaction(.explosion), at: 0.4, detail: .full)

    #expect(meanDistance(late) > 2 * meanDistance(early))
  }

  @Test("An explosion slows down: it gains more from 0.1 to 0.3 s than from 0.6 to 0.8 s")
  func explosionSlows() {
    let mean = { (time: Double) in
      meanDistance(Particles.particles(for: reaction(.explosion), at: time, detail: .full))
    }

    #expect(mean(0.3) - mean(0.1) > mean(0.8) - mean(0.6))
  }

  @Test("At 0.3 s an explosion has sparks in all four quadrants", arguments: [Detail.full, .half])
  func explosionCoversQuadrants(detail: Detail) {
    for seed: UInt64 in [1, 42, 999] {
      let sparks = Particles.particles(
        for: reaction(.explosion, seed: seed), at: 0.3, detail: detail)
      let quadrants = Set(sparks.map { [$0.x > 0, $0.y > 0] })

      #expect(quadrants.count == 4, "seed \(seed)")
    }
  }

  @Test("An explosion flashes at 0.05 s and not at 0.3 s")
  func explosionFlash() {
    let flash = { (time: Double) in
      visible(Particles.extras(for: reaction(.explosion), at: time)).filter { !isRing($0) }
    }

    #expect(!flash(0.05).isEmpty)
    #expect(flash(0.3).isEmpty)
  }

  @Test("An explosion's shock ring is larger at 0.3 s than at 0.1 s")
  func explosionShockRingGrows() throws {
    let ring = { (time: Double) in
      visible(Particles.extras(for: reaction(.explosion), at: time)).first(where: isRing)
    }

    let early = try #require(ring(0.1))
    let late = try #require(ring(0.3))
    #expect(late.radius > early.radius)
  }

  @Test("A drop falls: above the place at 0.1 s and 0.2 s, and lower at 0.2 s")
  func dropFalls() throws {
    let drop = { (time: Double) in
      Particles.particles(for: reaction(.drop), at: time, detail: .full).first
    }

    let early = try #require(drop(0.1))
    let late = try #require(drop(0.2))
    #expect(early.y < 0 && late.y < 0)
    #expect(late.y > early.y)
  }

  @Test("A drop has no ring before 0.3 s, and its rings at 1.0 s are larger than at 0.5 s")
  func dropRings() {
    let rings = { (time: Double) in
      visible(Particles.particles(for: reaction(.drop), at: time, detail: .full)).filter(isRing)
    }

    #expect(rings(0.1).isEmpty)
    #expect(rings(0.29).isEmpty)
    let middle = rings(0.5).map(\.radius).max() ?? 0
    let late = rings(1.0).map(\.radius).max() ?? 0
    #expect(middle > 0 && late > middle)
  }

  @Test("A drop's colour is one of its three colours, and the same seed gives the same colour")
  func dropColour() {
    let palette = [
      RGBColor(red: 0.45, green: 0.90, blue: 0.35),
      RGBColor(red: 0.70, green: 0.45, blue: 1.00),
      RGBColor(red: 1.00, green: 0.45, blue: 0.80),
    ]
    let colour = { (seed: UInt64) in
      Particles.particles(for: reaction(.drop, seed: seed), at: 0.1, detail: .full).first?.color
    }

    let colours = (UInt64(1)...30).compactMap(colour)
    #expect(colours.count == 30)
    #expect(colours.allSatisfy(palette.contains))
    #expect(Set(colours.map { [$0.red, $0.green, $0.blue] }).count == 3)
    #expect(colour(7) == colour(7))
  }
}
