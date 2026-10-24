/// One event as the session event tap receives it, reduced to the fields the policy reads.
/// The app fills it from the `CGEvent`, and from its `NSEvent` for a system-defined event.
public struct TapInput: Sendable, Equatable {
  /// The raw `CGEventType` value. System-defined events (14) have no case in `CGEventType`.
  public let eventType: UInt32
  public let keyCode: UInt16
  public let isAutorepeat: Bool
  /// The raw `CGEventFlags`, device-dependent bits included.
  public let rawFlags: UInt64
  /// `NSEvent.subtype` of a system-defined event, 0 otherwise.
  public let subtype: Int16
  /// `NSEvent.data1` of a system-defined event, 0 otherwise.
  public let data1: Int

  public init(
    eventType: UInt32, keyCode: UInt16 = 0, isAutorepeat: Bool = false, rawFlags: UInt64 = 0,
    subtype: Int16 = 0, data1: Int = 0
  ) {
    self.eventType = eventType
    self.keyCode = keyCode
    self.isAutorepeat = isAutorepeat
    self.rawFlags = rawFlags
    self.subtype = subtype
    self.data1 = data1
  }
}

/// What the tap does with one event.
public enum TapVerdict: Sendable, Equatable {
  /// Give the event back to the system unchanged.
  case pass
  /// Drop the event, and route `route` into the `KeyRouter` if there is one.
  case swallow(route: KeyEvent?)
  /// macOS turned the tap off because it answered too slowly. Turn it on again.
  case reenable
}

/// Decides what the session event tap does with each event. The tap exists only while the
/// kiosk runs, and in that time every key goes to the toy only, whichever app macOS says is in
/// front, so no global hotkey and no top-row function acts.
public enum KeyTapPolicy {
  /// Raw `CGEventType` values.
  public static let keyDownType: UInt32 = 10
  public static let keyUpType: UInt32 = 11
  public static let flagsChangedType: UInt32 = 12
  /// `NSEvent.EventType.systemDefined`. Media, volume and brightness keys arrive as these.
  public static let systemDefinedType: UInt32 = 14
  /// `CGEventType.tapDisabledByTimeout` and `.tapDisabledByUserInput`.
  public static let tapDisabledByTimeoutType: UInt32 = 0xFFFF_FFFE
  public static let tapDisabledByUserInputType: UInt32 = 0xFFFF_FFFF

  /// `NSEvent.ModifierFlags.deviceIndependentFlagsMask`. The bits below it name the left or
  /// right key and other device details that `ModifierFlags` does not hold.
  private static let deviceIndependentFlagsMask: UInt64 = 0xFFFF_0000

  /// The subtype of the aux control buttons: volume, brightness, media and keyboard light.
  private static let auxControlButtonsSubtype: Int16 = 8
  /// NX key type of the power key. It passes, so the system's power handling keeps working.
  private static let powerKeyType = 6
  private static let keyDownState = 0x0A

  /// Each media key type with the F-key whose place it takes. NX key types are from
  /// `IOKit/hidsystem/ev_keymap.h`, key codes from `HIToolbox/Events.h`.
  static let functionKeyByKeyType: [Int: UInt16] = [
    3: 122,  // brightness down: F1
    2: 120,  // brightness up: F2
    22: 96,  // keyboard light down: F5
    23: 96,  // keyboard light on or off: F5
    21: 97,  // keyboard light up: F6
    18: 98,  // previous: F7
    20: 98,  // rewind: F7
    16: 100,  // play: F8
    17: 101,  // next: F9
    19: 101,  // fast forward: F9
    7: 109,  // mute: F10
    1: 103,  // volume down: F11
    0: 111,  // volume up: F12
  ]

  /// One aux control button event, unpacked from `NSEvent.data1`.
  private struct AuxButton {
    let keyType: Int
    let isDown: Bool
    let isRepeat: Bool

    init(data1: Int) {
      keyType = (data1 >> 16) & 0xFFFF
      isDown = (data1 >> 8) & 0xFF == KeyTapPolicy.keyDownState
      isRepeat = data1 & 1 == 1
    }
  }

  public static func verdict(for input: TapInput) -> TapVerdict {
    // A tap that the user's input turned off stays off. The keys then act as without the tap.
    if input.eventType == tapDisabledByTimeoutType {
      return .reenable
    }
    switch input.eventType {
    case keyDownType:
      return .swallow(route: .keyDown(code: input.keyCode, isRepeat: input.isAutorepeat))
    case keyUpType:
      return .swallow(route: nil)
    case flagsChangedType:
      return .swallow(route: .flagsChanged(code: input.keyCode, flags: modifierFlags(of: input)))
    case systemDefinedType:
      return systemDefinedVerdict(for: input)
    default:
      return .pass
    }
  }

  /// Only the aux control buttons are taken, and of them every key but power. The other
  /// subtypes, such as power, mouse buttons, eject, sleep, restart and shutdown, pass.
  private static func systemDefinedVerdict(for input: TapInput) -> TapVerdict {
    guard input.subtype == auxControlButtonsSubtype else {
      return .pass
    }
    let button = AuxButton(data1: input.data1)
    guard button.keyType != powerKeyType else {
      return .pass
    }
    guard button.isDown, let code = functionKeyByKeyType[button.keyType] else {
      return .swallow(route: nil)
    }
    return .swallow(route: .keyDown(code: code, isRepeat: button.isRepeat))
  }

  /// The line to write to stderr for this event, if any: the tap went off, or a key arrived
  /// that the toy has no place for. The adult copies the line to report a key that still acts.
  public static func note(for input: TapInput) -> String? {
    if input.eventType == tapDisabledByUserInputType {
      return "BabyToy: macOS turned the key tap off because of user input."
        + " System keys act again until the toy restarts."
    }
    switch input.eventType {
    case keyDownType where !input.isAutorepeat, flagsChangedType:
      guard !KeyboardLayout.isMapped(input.keyCode) else {
        return nil
      }
      return "BabyToy: key code \(input.keyCode) is not in the key map."
    case systemDefinedType:
      return systemDefinedNote(for: input)
    default:
      return nil
    }
  }

  private static func systemDefinedNote(for input: TapInput) -> String? {
    let button = AuxButton(data1: input.data1)
    guard input.subtype == auxControlButtonsSubtype, button.isDown, !button.isRepeat,
      button.keyType != powerKeyType, functionKeyByKeyType[button.keyType] == nil
    else {
      return nil
    }
    return "BabyToy: swallowed system-defined key type \(button.keyType)"
      + " (subtype \(input.subtype), data1 \(input.data1)), which has no place in the key map."
  }

  /// The debug line for one event, written when `BABYTOY_DEBUG=1`: the event type, the key
  /// code and raw flags or the subtype, data1 and key type, and the verdict. It changes no
  /// decision. An auto-repeat key press gives `nil`, so that a held key
  /// does not flood the output.
  public static func debugLine(for input: TapInput, verdict: TapVerdict)
    -> String?
  {
    if input.eventType == keyDownType && input.isAutorepeat {
      return nil
    }
    var parts = [debugTypeName(of: input.eventType)]
    switch input.eventType {
    case keyDownType, keyUpType, flagsChangedType:
      parts.append("key code \(input.keyCode)")
      parts.append("flags 0x\(String(input.rawFlags, radix: 16))")
    case systemDefinedType:
      parts.append("subtype \(input.subtype)")
      parts.append("data1 \(input.data1)")
      parts.append("key type \(AuxButton(data1: input.data1).keyType)")
    default:
      break
    }
    parts.append(debugVerdictName(of: verdict))
    return "BabyToy debug: " + parts.joined(separator: ", ")
  }

  private static func debugTypeName(of eventType: UInt32) -> String {
    switch eventType {
    case keyDownType: "keyDown"
    case keyUpType: "keyUp"
    case flagsChangedType: "flagsChanged"
    case systemDefinedType: "systemDefined"
    case tapDisabledByTimeoutType: "tapDisabledByTimeout"
    case tapDisabledByUserInputType: "tapDisabledByUserInput"
    default: "other"
    }
  }

  private static func debugVerdictName(of verdict: TapVerdict) -> String {
    switch verdict {
    case .pass: "pass"
    case .swallow(let route): route == nil ? "swallow not routed" : "swallow routed"
    case .reenable: "reenable"
    }
  }

  private static func modifierFlags(of input: TapInput) -> ModifierFlags {
    ModifierFlags(rawValue: UInt(input.rawFlags & deviceIndependentFlagsMask))
  }
}
