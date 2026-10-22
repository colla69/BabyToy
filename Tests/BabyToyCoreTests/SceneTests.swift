import Testing

@testable import BabyToyCore

private let keyQ: UInt16 = 12

@Suite("Scene")
struct SceneTests {
  @Test("One press adds one reaction at the key's place")
  func onePressAddsOneReaction() {
    var scene = Scene()

    scene.press(keyCode: keyQ, at: 2)

    #expect(scene.reactions.count == 1)
    #expect(scene.reactions.first?.keyCode == keyQ)
    #expect(scene.reactions.first?.spawnTime == 2)
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

  @Test("Pruning removes the reactions at or past their lifetime and keeps the rest")
  func pruneRemovesExpired() {
    var scene = Scene()
    scene.press(keyCode: keyQ, at: 0)
    scene.press(keyCode: keyQ, at: 1)

    scene.prune(at: Scene.lifetime)

    #expect(scene.reactions.map(\.spawnTime) == [1])
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

  @Test("Letters and digits carry their label, other keys none")
  func labelsFollowKeyMap() {
    var scene = Scene()

    scene.press(keyCode: keyQ, at: 0)
    scene.press(keyCode: 18, at: 0)
    scene.press(keyCode: 56, at: 0)

    #expect(scene.reactions.map(\.label) == ["Q", "1", nil])
  }

  @Test("Each key group gets its own shape")
  func shapeByGroup() {
    var scene = Scene()

    for code: UInt16 in [keyQ, 18, 49, 56] {
      scene.press(keyCode: code, at: 0)
    }

    #expect(scene.reactions.map(\.shape) == [.circle, .star, .roundedSquare, .ring])
  }

  @Test("A reaction grows and has faded by 1.4 seconds")
  func growsAndFades() throws {
    var scene = Scene()
    scene.press(keyCode: keyQ, at: 0)
    let reaction = try #require(scene.reactions.first)

    #expect(reaction.scale(at: 0.1) < reaction.scale(at: 0.5))
    #expect(reaction.scale(at: 0.5) < reaction.scale(at: 1.4))
    #expect(reaction.opacity(at: 0.1) > 0.9)
    #expect(reaction.opacity(at: 1.4) < 0.05)
    #expect(reaction.opacity(at: Scene.lifetime) == 0)
  }
}
