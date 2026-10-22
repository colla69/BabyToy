import Testing

@testable import BabyToyCore

@Suite("Keyboard layout")
struct KeyboardLayoutTests {
  @Test("Q maps to the top-left quarter")
  func qIsTopLeft() {
    let q = KeyboardLayout.key(for: 12)

    #expect(q.x < 0.5 && q.y < 0.5)
  }

  @Test("Slash maps to the bottom-right quarter")
  func slashIsBottomRight() {
    let slash = KeyboardLayout.key(for: 44)

    #expect(slash.x > 0.5 && slash.y > 0.5)
  }

  @Test("Space maps to the bottom middle and is a big key")
  func spaceIsBottomMiddleBigKey() {
    let space = KeyboardLayout.key(for: 49)

    #expect(space.x > 0.35 && space.x < 0.65)
    #expect(space.y > 0.75)
    #expect(space.group == .bigKey)
  }

  @Test("Letters and digits carry their label and group")
  func lettersAndDigitsHaveLabels() {
    let q = KeyboardLayout.key(for: 12)
    let one = KeyboardLayout.key(for: 18)

    #expect(q.group == .letter && q.label == "Q")
    #expect(one.group == .digit && one.label == "1")
  }

  @Test(
    "An unknown key code returns a position inside the keyboard",
    arguments: [
      UInt16(10), 52, 66, 200, 999, UInt16.max,
    ])
  func unknownCodeIsValid(code: UInt16) {
    let key = KeyboardLayout.key(for: code)

    #expect((0...1).contains(key.x) && (0...1).contains(key.y))
    #expect(key.group == .other)
  }
}
