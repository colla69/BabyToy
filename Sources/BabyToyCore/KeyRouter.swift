/// One key event as the app receives it from AppKit.
public enum KeyEvent: Sendable, Equatable {
  case keyDown(code: UInt16, isRepeat: Bool)
  /// A modifier key went down or up. `flags` are all modifiers held after the change.
  case flagsChanged(code: UInt16, flags: ModifierFlags)
}

/// What the app does with one key event.
public enum KeyResponse: Sendable, Equatable {
  /// The exit combination is complete. Leave, and draw or play nothing for this key.
  case exit
  /// Draw a reaction for the key, and play its tone if `playsSound` is true.
  case react(keyCode: UInt16, playsSound: Bool)
  /// A modifier key went up. Nothing to show.
  case nothing
}

/// Decides what one key event does. The exit matcher sees every event first, so the adult's
/// way out works whatever the scene or the sound does.
public struct KeyRouter: Sendable {
  /// Caps Lock sends one event per press, and its flag goes off on every second press.
  private static let capsLockCode: UInt16 = 57

  private var exitCombination = ExitCombination()
  private var heldModifiers = ModifierFlags()

  public init() {}

  public mutating func route(_ event: KeyEvent) -> KeyResponse {
    if exitCombination.feed(Self.exitInput(for: event)) {
      return .exit
    }
    switch event {
    case .keyDown(let code, let isRepeat):
      return .react(keyCode: code, playsSound: !isRepeat)
    case .flagsChanged(let code, let flags):
      let wentDown = !flags.subtracting(heldModifiers).isEmpty || code == Self.capsLockCode
      heldModifiers = flags
      return wentDown ? .react(keyCode: code, playsSound: true) : .nothing
    }
  }

  private static func exitInput(for event: KeyEvent) -> ExitInput {
    switch event {
    case .keyDown(let code, let isRepeat): .keyDown(code: code, isRepeat: isRepeat)
    case .flagsChanged(_, let flags): .modifiersChanged(flags)
    }
  }
}
