/// Modifier flags with the bit values of `NSEvent.ModifierFlags`, so the app can pass
/// `event.modifierFlags.rawValue` straight in.
public struct ModifierFlags: OptionSet, Sendable, Hashable {
  public let rawValue: UInt

  public init(rawValue: UInt) {
    self.rawValue = rawValue
  }

  public static let capsLock = ModifierFlags(rawValue: 1 << 16)
  public static let shift = ModifierFlags(rawValue: 1 << 17)
  public static let control = ModifierFlags(rawValue: 1 << 18)
  public static let option = ModifierFlags(rawValue: 1 << 19)
  public static let command = ModifierFlags(rawValue: 1 << 20)
  public static let numericPad = ModifierFlags(rawValue: 1 << 21)
  public static let help = ModifierFlags(rawValue: 1 << 22)
  public static let function = ModifierFlags(rawValue: 1 << 23)
}

public enum ExitInput: Sendable, Equatable {
  case keyDown(code: UInt16, isRepeat: Bool)
  case modifiersChanged(ModifierFlags)
}

/// Recognises the adult's way out: hold Control + Option + Command and nothing else, then
/// press B, Y, E one at a time, in that order.
///
/// Any other key press resets it, and so does any change of the modifiers that count. A
/// flat-hand pile always brings an extra key, so mashing does not produce the sequence.
/// The matcher deliberately does not track which keys are down, because macOS does not
/// reliably send keyUp for keys pressed while Command is held.
public struct ExitCombination: Sendable {
  public static let requiredModifiers: ModifierFlags = [.control, .option, .command]
  /// B, Y, E as virtual key codes.
  public static let letterCodes: [UInt16] = [11, 16, 14]

  /// Caps Lock, the numeric-pad flag, the help flag and the device-dependent bits do not
  /// count: a child who turns Caps Lock on must not lock the adult in.
  private static let countedModifiers: ModifierFlags = [
    .shift, .control, .option, .command, .function,
  ]

  private var heldModifiers = ModifierFlags()
  private var lettersMatched = 0

  public init() {}

  /// Returns `true` when this input completes the exit combination.
  public mutating func feed(_ input: ExitInput) -> Bool {
    switch input {
    case .modifiersChanged(let flags):
      heldModifiers = flags.intersection(Self.countedModifiers)
      lettersMatched = 0
      return false
    case .keyDown(_, isRepeat: true):
      return false
    case .keyDown(let code, isRepeat: false):
      return advance(with: code)
    }
  }

  private mutating func advance(with code: UInt16) -> Bool {
    guard heldModifiers == Self.requiredModifiers, code == Self.letterCodes[lettersMatched]
    else {
      lettersMatched = 0
      return false
    }
    lettersMatched += 1
    guard lettersMatched == Self.letterCodes.count else {
      return false
    }
    lettersMatched = 0
    return true
  }
}
