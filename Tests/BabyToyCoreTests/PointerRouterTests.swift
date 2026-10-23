import CoreGraphics
import Testing

@testable import BabyToyCore

private let screen = CGSize(width: 1728, height: 1117)

private func place(of response: PointerResponse) -> (x: Double, y: Double)? {
  switch response {
  case .trail(let x, let y, _), .burst(let x, let y, _): (x, y)
  case .nothing: nil
  }
}

private func glide(of response: PointerResponse) -> Tone? {
  if case .trail(_, _, let glide) = response { glide } else { nil }
}

private func isTrail(_ response: PointerResponse) -> Bool {
  if case .trail = response { true } else { false }
}

private func step(of tone: Tone?) -> Int? {
  switch tone {
  case .note(let step), .glide(let step): step
  default: nil
  }
}

/// A router whose last glide was at the centre at time 0.2.
private func routerAfterGlide() -> PointerRouter {
  var router = PointerRouter()
  _ = router.route(.moved(dx: 200, dy: 0), at: 0, screen: screen)
  _ = router.route(.moved(dx: -200, dy: 0), at: 0.2, screen: screen)
  return router
}

@Suite("Pointer router")
struct PointerRouterTests {
  @Test("The pointer starts at the centre")
  func startsAtCentre() {
    var router = PointerRouter()

    let response = router.route(.pressed, at: 0, screen: screen)

    #expect(place(of: response)?.x == 0.5 && place(of: response)?.y == 0.5)
  }

  @Test("A move of a quarter of the screen width moves x by 0.25")
  func moveIsInScreenUnits() {
    var router = PointerRouter()

    let response = router.route(.moved(dx: screen.width / 4, dy: 0), at: 0, screen: screen)

    #expect(place(of: response)?.x == 0.75)
    #expect(place(of: response)?.y == 0.5)
  }

  @Test(
    "The pointer is clamped at every edge",
    arguments: [(-5000.0, 0.0, 0.0, 0.5), (5000, 0, 1, 0.5), (0, -5000, 0.5, 0), (0, 5000, 0.5, 1)])
  func clampedAtEdges(dx: Double, dy: Double, x: Double, y: Double) {
    var router = PointerRouter()

    let response = router.route(.moved(dx: dx, dy: dy), at: 0, screen: screen)

    #expect(place(of: response)?.x == x && place(of: response)?.y == y)
  }

  @Test("10,000 seeded random moves and scrolls never leave 0…1")
  func randomMovesStayInside() {
    var router = PointerRouter()
    var random = SeededRandom(seed: 3)

    for index in 0..<10_000 {
      let dx = Double.random(in: -400...400, using: &random)
      let dy = Double.random(in: -400...400, using: &random)
      let event: PointerEvent =
        index.isMultiple(of: 2) ? .moved(dx: dx, dy: dy) : .scrolled(dx: dx, dy: dy)
      let response = router.route(event, at: Double(index) * 0.05, screen: screen)
      if let spot = place(of: response) {
        #expect((0...1).contains(spot.x) && (0...1).contains(spot.y))
      }
    }
  }

  @Test("Moves less than 1/30 s apart give one trail")
  func trailsAreThrottled() {
    var router = PointerRouter()

    let first = router.route(.moved(dx: 10, dy: 0), at: 0, screen: screen)
    let second = router.route(.moved(dx: 10, dy: 0), at: 0.02, screen: screen)

    #expect(isTrail(first))
    #expect(second == .nothing)
  }

  @Test("A press gives a burst at the current place")
  func pressBurstsAtPlace() {
    var router = PointerRouter()
    _ = router.route(.moved(dx: -screen.width / 4, dy: screen.height / 4), at: 0, screen: screen)

    let response = router.route(.pressed, at: 0.01, screen: screen)

    guard case .burst(let x, let y, let note) = response else {
      Issue.record("got \(response)")
      return
    }
    #expect(x == 0.25 && y == 0.75)
    #expect(note == Tones.tone(forPointerX: 0.25))
  }

  @Test("A scroll moves the pointer and trails")
  func scrollMovesAndTrails() {
    var router = PointerRouter()

    let response = router.route(.scrolled(dx: 0, dy: screen.height / 4), at: 0, screen: screen)

    #expect(isTrail(response))
    #expect(place(of: response)?.y == 0.75)
  }

  @Test("A steady swipe glides at most once per 0.15 s")
  func swipeGlidesSteadily() {
    var router = PointerRouter()
    _ = router.route(.moved(dx: -screen.width, dy: 0), at: 0, screen: screen)
    let moves = 125
    var glides = 0

    for index in 1...moves {
      let response = router.route(
        .moved(dx: screen.width / Double(moves), dy: 0), at: Double(index) * 0.016,
        screen: screen)
      glides += glide(of: response) == nil ? 0 : 1
    }

    #expect((10...14).contains(glides), "\(glides) glides")
  }

  @Test("A jiggle makes no glide")
  func jiggleMakesNoGlide() {
    var router = PointerRouter()
    var glides = 0

    for index in 0..<200 {
      let dx = index.isMultiple(of: 2) ? 1.0 : -1.0
      let response = router.route(.moved(dx: dx, dy: -dx), at: Double(index) * 0.01, screen: screen)
      glides += glide(of: response) == nil ? 0 : 1
    }

    #expect(glides == 0)
  }

  @Test("After 0.15 s, a move of 0.03 of the width glides again, and 0.02 does not")
  func glideNeedsDistance() {
    var far = routerAfterGlide()
    var near = routerAfterGlide()

    let farResponse = far.route(.moved(dx: 0.03 * screen.width, dy: 0), at: 0.35, screen: screen)
    let nearResponse = near.route(
      .moved(dx: 0.02 * screen.width, dy: 0), at: 0.35, screen: screen)

    #expect(glide(of: farResponse) != nil)
    #expect(isTrail(nearResponse) && glide(of: nearResponse) == nil)
  }

  @Test("The setup glides at the centre after 0.2 s")
  func setupGlides() {
    var router = PointerRouter()
    let first = router.route(.moved(dx: 200, dy: 0), at: 0, screen: screen)
    let back = router.route(.moved(dx: -200, dy: 0), at: 0.2, screen: screen)

    #expect(glide(of: first) != nil)
    #expect(glide(of: back) != nil)
  }

  @Test("Scrolls share the throttle with moves")
  func scrollSharesThrottle() {
    var router = routerAfterGlide()

    let response = router.route(.scrolled(dx: 300, dy: 0), at: 0.25, screen: screen)

    #expect(isTrail(response) && glide(of: response) == nil)
  }

  @Test("A press is never throttled")
  func pressIsNeverThrottled() {
    var router = routerAfterGlide()

    let response = router.route(.pressed, at: 0.21, screen: screen)

    guard case .burst(let x, _, let note) = response else {
      Issue.record("got \(response)")
      return
    }
    #expect(note == Tones.tone(forPointerX: x))
  }

  @Test("The glide follows x: its step is the click note's step, lower at the left")
  func glideFollowsX() {
    for x in stride(from: 0.0, through: 1.0, by: 0.05) {
      #expect(step(of: Tones.glide(forPointerX: x)) == step(of: Tones.tone(forPointerX: x)))
    }
    let left = Tones.frequency(of: Tones.glide(forPointerX: 0.1))
    let right = Tones.frequency(of: Tones.glide(forPointerX: 0.9))
    #expect(left < right)
  }

  @Test("The pointer note rises with x and is in Tones.allTones")
  func pointerNoteRises() {
    let xs = stride(from: 0.0, through: 1.0, by: 0.01).map { $0 }
    let frequencies = xs.map { Tones.frequency(of: Tones.tone(forPointerX: $0)) }
    let built = Set(Tones.allTones)

    #expect(zip(frequencies, frequencies.dropFirst()).allSatisfy { $0 <= $1 })
    #expect((frequencies.first ?? 0) < (frequencies.last ?? 0))
    #expect(xs.allSatisfy { built.contains(Tones.tone(forPointerX: $0)) })
    #expect(xs.allSatisfy { built.contains(Tones.glide(forPointerX: $0)) })
  }
}
