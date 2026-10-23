import Testing

@testable import BabyToyCore

private let keyB: UInt16 = 11
private let keyY: UInt16 = 16
private let keyE: UInt16 = 14
private let keyJ: UInt16 = 38
private let leftShift: UInt16 = 56
private let leftControl: UInt16 = 59
private let leftOption: UInt16 = 58
private let leftCommand: UInt16 = 55
private let capsLock: UInt16 = 57

private func press(_ code: UInt16) -> KeyEvent {
  .keyDown(code: code, isRepeat: false)
}

private func routed(_ events: [KeyEvent]) -> [KeyResponse] {
  var router = KeyRouter()
  return events.map { router.route($0) }
}

@Suite("Key router")
struct KeyRouterTests {
  @Test("A key press draws and plays a sound")
  func keyPressReactsWithSound() {
    #expect(routed([press(keyJ)]) == [.react(keyCode: keyJ, playsSound: true)])
  }

  @Test("An auto-repeat draws but plays no sound")
  func repeatReactsWithoutSound() {
    let events: [KeyEvent] = [press(keyJ), .keyDown(code: keyJ, isRepeat: true)]
    #expect(routed(events).last == .react(keyCode: keyJ, playsSound: false))
  }

  @Test("A modifier going down draws and plays a sound")
  func modifierDownReacts() {
    let events: [KeyEvent] = [.flagsChanged(code: leftShift, flags: .shift)]
    #expect(routed(events) == [.react(keyCode: leftShift, playsSound: true)])
  }

  @Test("A modifier going up does nothing, while another one stays held")
  func modifierUpDoesNothing() {
    let events: [KeyEvent] = [
      .flagsChanged(code: leftShift, flags: .shift),
      .flagsChanged(code: leftControl, flags: [.shift, .control]),
      .flagsChanged(code: leftShift, flags: .control),
    ]
    #expect(routed(events).last == KeyResponse.nothing)
  }

  @Test("Turning Caps Lock off is a key press too")
  func capsLockOffReacts() {
    let events: [KeyEvent] = [
      .flagsChanged(code: capsLock, flags: .capsLock),
      .flagsChanged(code: capsLock, flags: []),
    ]
    #expect(routed(events).last == .react(keyCode: capsLock, playsSound: true))
  }

  @Test("The exit combination exits on E, and E draws nothing")
  func exitCombinationExits() {
    let events: [KeyEvent] = [
      .flagsChanged(code: leftControl, flags: .control),
      .flagsChanged(code: leftOption, flags: [.control, .option]),
      .flagsChanged(code: leftCommand, flags: [.control, .option, .command]),
      press(keyB), press(keyY), press(keyE),
    ]
    let responses = routed(events)
    #expect(responses.last == .exit)
    #expect(responses.dropLast().allSatisfy { $0 != .exit })
  }

  @Test("The exit letters without the modifiers only draw")
  func lettersWithoutModifiersReact() {
    let responses = routed([press(keyB), press(keyY), press(keyE)])
    #expect(responses.allSatisfy { $0 != .exit })
  }
}
