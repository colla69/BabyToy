import AppKit
import BabyToyCore

/// The session event tap. It sees every key before the system's hotkeys and top-row
/// functions act, and `KeyTapPolicy` in BabyToyCore decides what each event does. Creating
/// it needs the Accessibility permission.
@MainActor
final class KeyTap {
  /// keyDown, keyUp, flagsChanged and system-defined events. macOS sends the tap-disabled
  /// events whatever the mask holds.
  private static let eventMask: CGEventMask = [
    KeyTapPolicy.keyDownType, KeyTapPolicy.keyUpType, KeyTapPolicy.flagsChangedType,
    KeyTapPolicy.systemDefinedType,
  ].reduce(0) { $0 | 1 << CGEventMask($1) }

  private let onKey: @MainActor (KeyEvent) -> Void
  private let isDebug: Bool
  private var port: CFMachPort?
  private var source: CFRunLoopSource?

  /// `onKey` gets each key event that the policy routes. With `isDebug`, every event the tap
  /// receives is also described on stderr.
  init(isDebug: Bool, onKey: @escaping @MainActor (KeyEvent) -> Void) {
    self.isDebug = isDebug
    self.onKey = onKey
  }

  /// Returns `false` if macOS refuses the tap.
  func start() -> Bool {
    // Unretained: the owner keeps this object alive until `stop()`, and after `stop()` the
    // callback no longer runs.
    let userInfo = Unmanaged.passUnretained(self).toOpaque()
    guard
      let port = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
        eventsOfInterest: Self.eventMask, callback: keyTapCallback, userInfo: userInfo)
    else {
      return false
    }
    let source = CFMachPortCreateRunLoopSource(nil, port, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: port, enable: true)
    self.port = port
    self.source = source
    return true
  }

  func stop() {
    if let port {
      CGEvent.tapEnable(tap: port, enable: false)
      CFMachPortInvalidate(port)
    }
    if let source {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
    }
    port = nil
    source = nil
  }

  /// Returns `true` to pass the event on, `false` to swallow it.
  fileprivate func passes(_ input: TapInput) -> Bool {
    if let note = KeyTapPolicy.note(for: input) {
      FileHandle.standardError.write(Data("\(note)\n".utf8))
    }
    let verdict = KeyTapPolicy.verdict(for: input)
    if isDebug, let line = KeyTapPolicy.debugLine(for: input, verdict: verdict) {
      FileHandle.standardError.write(Data("\(line)\n".utf8))
    }
    switch verdict {
    case .pass:
      return true
    case .swallow(let route):
      if let route {
        onKey(route)
      }
      return false
    case .reenable:
      if let port {
        CGEvent.tapEnable(tap: port, enable: true)
      }
      return true
    }
  }

  /// Runs in the C callback, before the hop to the main actor, so that only the `Sendable`
  /// input crosses.
  fileprivate nonisolated static func tapInput(type: CGEventType, event: CGEvent) -> TapInput {
    let eventType = type.rawValue
    switch eventType {
    case KeyTapPolicy.keyDownType, KeyTapPolicy.keyUpType, KeyTapPolicy.flagsChangedType:
      return TapInput(
        eventType: eventType,
        keyCode: UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode)),
        isAutorepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
        rawFlags: event.flags.rawValue)
    case KeyTapPolicy.systemDefinedType:
      // `CGEvent` has no field for the subtype and data1 of a system-defined event.
      guard let systemEvent = NSEvent(cgEvent: event) else {
        return TapInput(eventType: eventType)
      }
      return TapInput(
        eventType: eventType, subtype: systemEvent.subtype.rawValue, data1: systemEvent.data1)
    default:
      return TapInput(eventType: eventType)
    }
  }
}

private func keyTapCallback(
  proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let userInfo else {
    return Unmanaged.passUnretained(event)
  }
  let keyTap = Unmanaged<KeyTap>.fromOpaque(userInfo).takeUnretainedValue()
  let input = KeyTap.tapInput(type: type, event: event)
  // The tap's source is on the main run loop, so the callback runs on the main thread.
  let passes = MainActor.assumeIsolated {
    keyTap.passes(input)
  }
  return passes ? Unmanaged.passUnretained(event) : nil
}
