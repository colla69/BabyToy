import AppKit

/// A borderless window that covers one whole screen.
final class KioskWindow: NSWindow {
  init(screen: NSScreen) {
    super.init(
      contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    isReleasedWhenClosed = false
    backgroundColor = .black
    setFrame(screen.frame, display: false)
  }

  /// A borderless window answers `false` by default, and then it never gets key events.
  override var canBecomeKey: Bool { true }

  override var canBecomeMain: Bool { true }
}
