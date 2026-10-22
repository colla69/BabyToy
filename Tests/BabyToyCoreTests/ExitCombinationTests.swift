import Testing

@testable import BabyToyCore

private let keyB: UInt16 = 11
private let keyY: UInt16 = 16
private let keyE: UInt16 = 14
private let keyH: UInt16 = 4
private let keyN: UInt16 = 45
private let keyV: UInt16 = 9
private let keyG: UInt16 = 5

private let exitModifiers: ModifierFlags = [.control, .option, .command]

private func press(_ code: UInt16) -> ExitInput {
  .keyDown(code: code, isRepeat: false)
}

private func hold(_ flags: ModifierFlags) -> ExitInput {
  .modifiersChanged(flags)
}

/// Feeds every input and returns the index of each input that made the matcher fire.
private func firingIndices(_ inputs: [ExitInput], into matcher: inout ExitCombination) -> [Int] {
  inputs.indices.filter { matcher.feed(inputs[$0]) }
}

private func firingIndices(_ inputs: [ExitInput]) -> [Int] {
  var matcher = ExitCombination()
  return firingIndices(inputs, into: &matcher)
}

private let cleanCombination = [hold(exitModifiers), press(keyB), press(keyY), press(keyE)]

/// Random key presses, repeats and modifier changes, the way a child's hands produce them.
private func mash(count: Int, seed: UInt64) -> [ExitInput] {
  var random = SeededRandom(seed: seed)
  return (0..<count).map { _ in
    if Int.random(in: 0..<5, using: &random) == 0 {
      let flagBits = UInt.random(in: 0...0xFF, using: &random) << 16
      let deviceBits = UInt.random(in: 0...0xFF, using: &random)
      return .modifiersChanged(ModifierFlags(rawValue: flagBits | deviceBits))
    }
    let code = UInt16.random(in: 0..<128, using: &random)
    let isRepeat = Int.random(in: 0..<10, using: &random) == 0
    return .keyDown(code: code, isRepeat: isRepeat)
  }
}

@Suite("Exit combination")
struct ExitCombinationTests {
  @Test("The exact combination exits on E and not before")
  func exactCombinationExits() {
    #expect(firingIndices(cleanCombination) == [3])
  }

  @Test(
    "Letters out of order do not exit",
    arguments: [
      [keyB, keyE, keyY], [keyY, keyB, keyE], [keyY, keyE, keyB], [keyE, keyB, keyY],
      [keyE, keyY, keyB], [keyB, keyY, keyY, keyE],
    ])
  func lettersOutOfOrderReset(letters: [UInt16]) {
    #expect(firingIndices([hold(exitModifiers)] + letters.map(press)).isEmpty)
  }

  @Test("An extra key between the letters resets", arguments: [1, 2])
  func extraKeyBetweenLettersResets(position: Int) {
    var inputs = cleanCombination
    inputs.insert(press(keyH), at: position + 1)

    #expect(firingIndices(inputs).isEmpty)
  }

  @Test("Adding Shift or fn mid-way resets", arguments: [ModifierFlags.shift, .function])
  func addingShiftOrFnResets(extra: ModifierFlags) {
    let addedThenReleased = [
      hold(exitModifiers), press(keyB), hold(exitModifiers.union(extra)), hold(exitModifiers),
      press(keyY), press(keyE),
    ]
    let heldFromStart = [hold(exitModifiers.union(extra)), press(keyB), press(keyY), press(keyE)]

    #expect(firingIndices(addedThenReleased).isEmpty)
    #expect(firingIndices(heldFromStart).isEmpty)
  }

  @Test(
    "Releasing a modifier mid-way resets", arguments: [ModifierFlags.control, .option, .command])
  func releasingModifierResets(released: ModifierFlags) {
    let inputs = [
      hold(exitModifiers), press(keyB), hold(exitModifiers.subtracting(released)),
      hold(exitModifiers), press(keyY), press(keyE),
    ]

    #expect(firingIndices(inputs).isEmpty)
  }

  @Test(
    "The letters without the exact modifiers do nothing",
    arguments: [ModifierFlags(), [.control, .option], [.control, .command], [.option, .command]])
  func lettersWithoutModifiersDoNothing(flags: ModifierFlags) {
    #expect(firingIndices([hold(flags), press(keyB), press(keyY), press(keyE)]).isEmpty)
  }

  @Test(
    "A pile with B, Y and other keys does not exit",
    arguments: [
      [keyV, keyB, keyY, keyG, keyH], [keyB, keyY, keyN, keyE, keyH],
      [keyG, keyB, keyH, keyY, keyE],
    ])
  func pileDoesNotExit(pile: [UInt16]) {
    #expect(firingIndices([hold(exitModifiers)] + pile.map(press)).isEmpty)
  }

  @Test("Auto-repeats of a letter are ignored")
  func autoRepeatIsIgnored() {
    let inputs = [
      hold(exitModifiers), press(keyB), .keyDown(code: keyB, isRepeat: true), press(keyY),
      .keyDown(code: keyY, isRepeat: true), press(keyE),
    ]

    #expect(firingIndices(inputs) == [5])
  }

  @Test(
    "Caps Lock, numeric-pad and help flags do not block the exit",
    arguments: [ModifierFlags.capsLock, .numericPad, .help])
  func ignoredFlagsDoNotBlockExit(ignored: ModifierFlags) {
    let inputs = [hold(exitModifiers.union(ignored)), press(keyB), press(keyY), press(keyE)]

    #expect(firingIndices(inputs) == [3])
  }

  @Test("Device-dependent bits, such as left or right Control, do not block the exit")
  func deviceDependentBitsAreIgnored() {
    let leftControlAndRightCommand = ModifierFlags(
      rawValue: exitModifiers.rawValue | 0x0001 | 0x0010)
    let inputs = [hold(leftControlAndRightCommand), press(keyB), press(keyY), press(keyE)]

    #expect(firingIndices(inputs) == [3])
  }

  @Test("100,000 seeded random mash events never exit")
  func randomMashNeverExits() {
    #expect(firingIndices(mash(count: 100_000, seed: 0xBABE)).isEmpty)
  }

  @Test("A mash followed by the clean combination exits")
  func mashThenCleanCombinationExits() {
    var matcher = ExitCombination()
    _ = firingIndices(mash(count: 10_000, seed: 42), into: &matcher)

    #expect(firingIndices(cleanCombination, into: &matcher) == [3])
  }
}
