import Testing

@testable import BabyToyCore

private let keyB: UInt16 = 11
private let keyY: UInt16 = 16
private let keyE: UInt16 = 14
private let keyJ: UInt16 = 38
private let leftControl: UInt16 = 59
private let leftOption: UInt16 = 58
private let space: UInt16 = 49
private let leftCommand: UInt16 = 55

/// `CGEventFlags` bits as the tap delivers them.
private let controlFlag: UInt64 = 0x4_0000
private let optionFlag: UInt64 = 0x8_0000
private let commandFlag: UInt64 = 0x10_0000
/// `NX_NONCOALSESCEDMASK`, set on most events the tap sees.
private let nonCoalescedBit: UInt64 = 0x100

private func keyDown(_ code: UInt16, flags: UInt64 = nonCoalescedBit, isRepeat: Bool = false)
  -> TapInput
{
  TapInput(
    eventType: KeyTapPolicy.keyDownType, keyCode: code, isAutorepeat: isRepeat, rawFlags: flags)
}

private func keyUp(_ code: UInt16) -> TapInput {
  TapInput(eventType: KeyTapPolicy.keyUpType, keyCode: code, rawFlags: nonCoalescedBit)
}

private func flagsChanged(_ code: UInt16, flags: UInt64) -> TapInput {
  TapInput(eventType: KeyTapPolicy.flagsChangedType, keyCode: code, rawFlags: flags)
}

/// NX key types of the aux control buttons, from `IOKit/hidsystem/ev_keymap.h`.
private let soundUp = 0
private let power = 6

private let auxControlButtons: Int16 = 8
private let keyDownState = 0x0A
private let keyUpState = 0x0B

/// A system-defined event of the aux control buttons, packed as `NSEvent.data1` packs it.
private func auxButton(_ keyType: Int, state: Int = keyDownState, isRepeat: Bool = false)
  -> TapInput
{
  systemDefined(subtype: auxControlButtons, data1: keyType << 16 | state << 8 | (isRepeat ? 1 : 0))
}

private func systemDefined(subtype: Int16, data1: Int = 0) -> TapInput {
  TapInput(eventType: KeyTapPolicy.systemDefinedType, subtype: subtype, data1: data1)
}

@Suite("Key tap policy")
struct KeyTapPolicyTests {
  @Test("There is no pass case for key events: press, release and modifier change are swallowed")
  func keyEventsAreNeverPassed() {
    let inputs = [keyDown(keyJ), keyUp(keyJ), flagsChanged(leftCommand, flags: commandFlag)]

    #expect(
      inputs.allSatisfy {
        if case .swallow = KeyTapPolicy.verdict(for: $0) { true } else { false }
      })
  }

  @Test("A key press is swallowed and routed")
  func keyPressIsRouted() {
    let verdict = KeyTapPolicy.verdict(for: keyDown(keyJ))

    #expect(verdict == .swallow(route: .keyDown(code: keyJ, isRepeat: false)))
  }

  @Test("An auto-repeat key press is routed as a repeat")
  func keyRepeatIsRouted() {
    let verdict = KeyTapPolicy.verdict(for: keyDown(keyJ, isRepeat: true))

    #expect(verdict == .swallow(route: .keyDown(code: keyJ, isRepeat: true)))
  }

  @Test("A key release is swallowed and not routed")
  func keyReleaseIsSwallowed() {
    let verdict = KeyTapPolicy.verdict(for: keyUp(keyJ))

    #expect(verdict == .swallow(route: nil))
  }

  @Test("A modifier change is swallowed and routed with device bits removed")
  func modifierChangeIsRouted() {
    let leftCommandDeviceBit: UInt64 = 0x8
    let input = flagsChanged(
      leftCommand, flags: commandFlag | leftCommandDeviceBit | nonCoalescedBit)

    let verdict = KeyTapPolicy.verdict(for: input)

    #expect(verdict == .swallow(route: .flagsChanged(code: leftCommand, flags: .command)))
  }

  @Test("Command+Space is swallowed and routed to Space")
  func commandSpaceIsSwallowed() {
    let verdict = KeyTapPolicy.verdict(
      for: keyDown(space, flags: commandFlag | nonCoalescedBit))

    #expect(verdict == .swallow(route: .keyDown(code: space, isRepeat: false)))
  }

  @Test("Volume up goes down as a press of F12")
  func volumeUpRoutesToF12() {
    #expect(auxButton(soundUp).data1 == 0x000A00)

    let verdict = KeyTapPolicy.verdict(for: auxButton(soundUp))

    #expect(verdict == .swallow(route: .keyDown(code: 111, isRepeat: false)))
  }

  @Test("The release of a media key is swallowed and not routed")
  func mediaKeyUpRoutesNothing() {
    let input = auxButton(soundUp, state: keyUpState)

    #expect(input.data1 == 0x000B00)
    #expect(KeyTapPolicy.verdict(for: input) == .swallow(route: nil))
  }

  @Test("The repeat bit of a media key makes a repeat")
  func mediaKeyRepeatIsRepeat() {
    let verdict = KeyTapPolicy.verdict(
      for: auxButton(soundUp, isRepeat: true))

    #expect(verdict == .swallow(route: .keyDown(code: 111, isRepeat: true)))
  }

  @Test(
    "Every mapped media key type routes to a key of the top row",
    arguments: [0, 1, 2, 3, 7, 16, 17, 18, 19, 20, 21, 22, 23])
  func mappedKeyTypeRoutesToTopRow(keyType: Int) {
    let topRow = KeyboardLayout.mappedCodesByRow[0]

    let verdict = KeyTapPolicy.verdict(for: auxButton(keyType))

    guard case .swallow(route: .keyDown(let code, isRepeat: false)) = verdict else {
      Issue.record("key type \(keyType) gave \(verdict)")
      return
    }
    #expect(topRow.contains(code))
  }

  @Test("An unmapped media key type is swallowed and not routed")
  func unmappedKeyTypeIsSwallowed() {
    let launchPanel = 13

    let verdict = KeyTapPolicy.verdict(for: auxButton(launchPanel))

    #expect(verdict == .swallow(route: nil))
  }

  @Test("The power key passes")
  func powerKeyPasses() {
    #expect(KeyTapPolicy.verdict(for: auxButton(power)) == .pass)
  }

  @Test(
    "System-defined events of other subtypes pass",
    arguments: [Int16(1), 7, 10, 11, 12, 13])
  func otherSubtypesPass(subtype: Int16) {
    let verdict = KeyTapPolicy.verdict(for: systemDefined(subtype: subtype))

    #expect(verdict == .pass)
  }

  @Test("A tap turned off by a timeout is turned on again")
  func timeoutReenables() {
    let input = TapInput(eventType: KeyTapPolicy.tapDisabledByTimeoutType)

    #expect(KeyTapPolicy.verdict(for: input) == .reenable)
  }

  @Test("A tap turned off by user input stays off and says so")
  func userInputLeavesTapOff() {
    let input = TapInput(eventType: KeyTapPolicy.tapDisabledByUserInputType)

    #expect(KeyTapPolicy.verdict(for: input) == .pass)
    #expect(KeyTapPolicy.note(for: input) != nil)
  }

  @Test("An unmapped media key type writes a note")
  func unmappedKeyTypeWritesNote() {
    let launchPanel = 13

    #expect(KeyTapPolicy.note(for: auxButton(launchPanel)) != nil)
  }

  @Test("A key code outside the key map writes a note")
  func unmappedKeyCodeWritesNote() {
    let keypadFive: UInt16 = 87

    #expect(KeyTapPolicy.note(for: keyDown(keypadFive)) != nil)
  }

  @Test("A mapped key, a mapped media key and a top-row alias write no note")
  func mappedKeysWriteNoNote() {
    let missionControl: UInt16 = 160
    let inputs = [keyDown(keyJ), auxButton(soundUp), keyDown(missionControl)]

    #expect(inputs.allSatisfy { KeyTapPolicy.note(for: $0) == nil })
  }

  @Test("The debug line of a key press names the code, the flags and the swallow")
  func debugLineOfActiveKeyDown() throws {
    let input = keyDown(keyJ, flags: commandFlag | nonCoalescedBit)
    let verdict = KeyTapPolicy.verdict(for: input)

    let line = try #require(
      KeyTapPolicy.debugLine(for: input, verdict: verdict))

    #expect(line.contains("keyDown"))
    #expect(line.contains("key code 38"))
    #expect(line.contains("flags 0x100100"))
    #expect(!line.contains("active"))
    #expect(line.contains("swallow routed"))
  }

  @Test("The debug line of a key release says swallow not routed")
  func debugLineOfKeyUp() throws {
    let verdict = KeyTapPolicy.verdict(for: keyUp(keyJ))

    let line = try #require(
      KeyTapPolicy.debugLine(for: keyUp(keyJ), verdict: verdict))

    #expect(line.contains("keyUp"))
    #expect(line.contains("swallow not routed"))
  }

  @Test("The debug line of volume up names the subtype, data1 and key type 0")
  func debugLineOfVolumeUp() throws {
    let input = auxButton(soundUp)
    let verdict = KeyTapPolicy.verdict(for: input)

    let line = try #require(
      KeyTapPolicy.debugLine(for: input, verdict: verdict))

    #expect(line.contains("systemDefined"))
    #expect(line.contains("subtype 8"))
    #expect(line.contains("data1 2560"))
    #expect(line.contains("key type 0"))
    #expect(line.contains("swallow routed"))
  }

  @Test("The debug line of a tap turned off by a timeout says reenable")
  func debugLineOfTimeout() throws {
    let input = TapInput(eventType: KeyTapPolicy.tapDisabledByTimeoutType)
    let verdict = KeyTapPolicy.verdict(for: input)

    let line = try #require(
      KeyTapPolicy.debugLine(for: input, verdict: verdict))

    #expect(line.contains("tapDisabledByTimeout"))
    #expect(line.contains("reenable"))
  }

  @Test("The debug line names an event type it does not know as other")
  func debugLineOfUnknownType() throws {
    let input = TapInput(eventType: 99)

    let line = try #require(
      KeyTapPolicy.debugLine(for: input, verdict: .pass))

    #expect(line.contains("other"))
  }

  @Test("An auto-repeat key press writes no debug line")
  func debugLineSkipsAutorepeat() {
    let input = keyDown(keyJ, isRepeat: true)
    let verdict = KeyTapPolicy.verdict(for: input)

    #expect(KeyTapPolicy.debugLine(for: input, verdict: verdict) == nil)
  }

  @Test("The exit combination, through the tap and the key router, exits")
  func exitCombinationThroughTap() {
    let leftControlDeviceBit: UInt64 = 0x1
    let leftOptionDeviceBit: UInt64 = 0x20
    let leftCommandDeviceBit: UInt64 = 0x8
    let control = controlFlag | leftControlDeviceBit | nonCoalescedBit
    let controlOption = control | optionFlag | leftOptionDeviceBit
    let all = controlOption | commandFlag | leftCommandDeviceBit
    let inputs = [
      flagsChanged(leftControl, flags: control),
      flagsChanged(leftOption, flags: controlOption),
      flagsChanged(leftCommand, flags: all),
      keyDown(keyB, flags: all), keyUp(keyB),
      keyDown(keyY, flags: all), keyUp(keyY),
      keyDown(keyE, flags: all),
    ]
    var router = KeyRouter()

    let responses = inputs.compactMap { input -> KeyResponse? in
      guard case .swallow(route: let event?) = KeyTapPolicy.verdict(for: input)
      else {
        return nil
      }
      return router.route(event)
    }

    #expect(responses.last == .exit)
    #expect(responses.dropLast().allSatisfy { $0 != .exit })
  }
}
