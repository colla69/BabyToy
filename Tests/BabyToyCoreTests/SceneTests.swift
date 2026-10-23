import Testing

@testable import BabyToyCore

private let keyQ: UInt16 = 12
private let keyW: UInt16 = 13
private let keyR: UInt16 = 15
private let keyA: UInt16 = 0

@Suite("Scene")
struct SceneTests {
  @Test("One press adds one reaction at its spawn time")
  func onePressAddsOneReaction() {
    var scene = Scene()

    scene.press(keyCode: keyQ, at: 2)

    #expect(scene.reactions.count == 1)
    #expect(scene.reactions.first?.spawnTime == 2)
    #expect(scene.reactions.first?.strength == .burst)
  }

  @Test("10 presses in one burst add 10 reactions")
  func burstAddsTen() {
    var scene = Scene()

    for code in UInt16(0)..<10 {
      scene.press(keyCode: code, at: 0)
    }

    #expect(scene.reactions.count == 10)
  }

  @Test("1,000 presses leave exactly 200 reactions, all of them the newest")
  func capKeepsNewest() {
    var scene = Scene()
    let times = (0..<1000).map { Double($0) * 0.0001 }

    for (index, time) in times.enumerated() {
      scene.press(keyCode: UInt16(index % 128), at: time)
    }

    #expect(scene.reactions.map(\.spawnTime) == Array(times.suffix(Scene.maxReactions)))
  }

  @Test("1,000 mixed presses, bursts and trails leave the 200 newest")
  func mixedCapKeepsNewest() {
    var scene = Scene()
    let times = (0..<1000).map { Double($0) * 0.0001 }

    for (index, time) in times.enumerated() {
      switch index % 3 {
      case 0: scene.press(keyCode: UInt16(index % 128), at: time)
      case 1: scene.burst(x: 0.3, y: 0.6, at: time)
      default: scene.trail(x: 0.7, y: 0.2, at: time)
      }
    }

    #expect(scene.reactions.map(\.spawnTime) == Array(times.suffix(Scene.maxReactions)))
  }

  @Test("Pruning removes the reactions at or past their lifetime and keeps the rest")
  func pruneRemovesExpired() {
    var scene = Scene()
    scene.press(keyCode: keyQ, at: 0)
    scene.trail(x: 0.5, y: 0.5, at: 0.5)
    scene.press(keyCode: keyQ, at: 1)

    scene.prune(at: Scene.lifetime)

    #expect(scene.reactions.map(\.spawnTime) == [0.5, 1])
  }

  @Test("A reaction sits within a little jitter of its key's place")
  func positionFollowsKeyMap() {
    var scene = Scene()
    let key = KeyboardLayout.key(for: keyQ)

    for _ in 0..<50 {
      scene.press(keyCode: keyQ, at: 0)
    }

    for reaction in scene.reactions {
      #expect(abs(reaction.x - key.x) <= 0.05 && abs(reaction.y - key.y) <= 0.05)
    }
    #expect(Set(scene.reactions.map(\.x)).count > 1)
  }

  @Test("A press takes its key's effect")
  func pressTakesKeyEffect() {
    var scene = Scene()

    for code in [keyQ, keyA, keyR, keyW] {
      scene.press(keyCode: code, at: 0)
    }

    #expect(scene.reactions.map(\.element) == [.water, .fire, .explosion, .drop])
  }

  @Test("The same key gives the same effect under different scene seeds")
  func keyEffectIgnoresSeed() {
    let elements = (UInt64(1)...20).map { seed -> Element? in
      var scene = Scene(seed: seed)
      scene.press(keyCode: keyQ, at: 0)
      return scene.reactions.first?.element
    }

    #expect(Set(elements) == [.water])
  }

  @Test("A burst and a trail take the effect of their place, and their strength")
  func pointerTakesPlaceEffect() {
    var scene = Scene()
    let places = [(0.04, 0.08), (0.12, 0.08), (0.20, 0.08), (0.29, 0.08), (0.95, 0.95)]

    for (x, y) in places {
      scene.burst(x: x, y: y, at: 0)
      scene.trail(x: x, y: y, at: 0)
    }

    let expected = places.flatMap { x, y in [Element.at(x: x, y: y), Element.at(x: x, y: y)] }
    #expect(scene.reactions.map(\.element) == expected)
    #expect(Set(expected).count == 4)
  }

  @Test("A burst and a trail sit at the pointer's place, with their own strength")
  func pointerReactionsSitAtPlace() {
    var scene = Scene()

    scene.burst(x: 0.3, y: 0.7, at: 0)
    scene.trail(x: 0.6, y: 0.1, at: 0)

    #expect(scene.reactions.map(\.strength) == [.burst, .trail])
    #expect(scene.reactions.map(\.x) == [0.3, 0.6])
    #expect(scene.reactions.map(\.y) == [0.7, 0.1])
  }

  @Test("Each reaction gets its own seed")
  func eachReactionHasOwnSeed() {
    var scene = Scene()

    for index in 0..<100 {
      scene.press(keyCode: keyQ, at: Double(index))
    }

    #expect(Set(scene.reactions.map(\.seed)).count == 100)
  }

  @Test("The same seed and the same presses give equal scenes")
  func sameSeedSameScene() {
    func played(seed: UInt64) -> [Reaction] {
      var scene = Scene(seed: seed)
      scene.press(keyCode: keyQ, at: 0)
      scene.burst(x: 0.4, y: 0.6, at: 0.1)
      scene.trail(x: 0.2, y: 0.3, at: 0.2)
      scene.press(keyCode: keyR, at: 0.3)
      return scene.reactions
    }

    #expect(played(seed: 9) == played(seed: 9))
    #expect(played(seed: 9) != played(seed: 10))
  }
}
