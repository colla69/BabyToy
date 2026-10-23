import AppKit
import BabyToyCore

/// Starts the kiosk and never returns. The process ends through `AppDelegate.leave()`.
@MainActor
func runKiosk(exitAfterSeconds: Double?) {
  let app = NSApplication.shared
  // A bare executable starts as `.prohibited`: it cannot become active or get the keyboard.
  app.setActivationPolicy(.regular)
  // `NSApplication.delegate` is weak, so this local keeps the delegate alive while `run()`
  // runs.
  let delegate = AppDelegate(exitAfterSeconds: exitAfterSeconds)
  app.delegate = delegate
  app.run()
  withExtendedLifetime(delegate) {}
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  /// What the system may do while the toy is the active app. `.hideMenuBar` needs
  /// `.hideDock`, and the `disable` options need the Dock and the menu bar hidden.
  private static let kioskOptions: NSApplication.PresentationOptions = [
    .hideDock,
    .hideMenuBar,
    .disableProcessSwitching,
    .disableForceQuit,
    .disableSessionTermination,
    .disableHideApplication,
    .disableAppleMenu,
  ]

  private let exitAfterSeconds: Double?
  private var window: KioskWindow?
  private var toyView: ToyView?
  private var soundPlayer: SoundPlayer?
  private var router = KeyRouter()
  private var keyMonitor: Any?
  private var exitTimer: Task<Void, Never>?
  /// Set only by `leave()`. Until then every quit is refused.
  private var isLeaving = false

  init(exitAfterSeconds: Double?) {
    self.exitAfterSeconds = exitAfterSeconds
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    let app = NSApplication.shared
    app.mainMenu = nil
    showWindow()
    app.presentationOptions = Self.kioskOptions
    NSCursor.hide()
    startKeyMonitor()
    startSound()
    startExitTimer()
    app.activate()
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    isLeaving ? .terminateNow : .terminateCancel
  }

  private func showWindow() {
    guard let screen = NSScreen.screens.first else {
      fatalError("BabyToy found no screen to show the toy on")
    }
    let window = KioskWindow(screen: screen)
    let toyView = ToyView(frame: NSRect(origin: .zero, size: screen.frame.size))
    window.contentView = toyView
    window.makeKeyAndOrderFront(nil)
    self.window = window
    self.toyView = toyView
  }

  /// The one place where keys arrive. It returns `nil`, so AppKit acts on no key at all:
  /// no shortcut, no menu, no beep.
  private func startKeyMonitor() {
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) {
      [weak self] event in
      MainActor.assumeIsolated {
        self?.handle(event)
      }
      return nil
    }
  }

  private func handle(_ event: NSEvent) {
    guard let keyEvent = Self.keyEvent(from: event) else {
      return
    }
    switch router.route(keyEvent) {
    case .exit:
      leave()
    case .react(let keyCode, let playsSound):
      toyView?.press(keyCode: keyCode)
      if playsSound {
        soundPlayer?.play(keyCode: keyCode)
      }
    case .nothing:
      break
    }
  }

  private static func keyEvent(from event: NSEvent) -> KeyEvent? {
    switch event.type {
    case .keyDown:
      return .keyDown(code: event.keyCode, isRepeat: event.isARepeat)
    case .flagsChanged:
      let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
      return .flagsChanged(code: event.keyCode, flags: ModifierFlags(rawValue: flags.rawValue))
    default:
      return nil
    }
  }

  private func startSound() {
    soundPlayer = SoundPlayer()
    soundPlayer?.start()
  }

  /// `--exit-after` leaves through the same path as the exit combination.
  private func startExitTimer() {
    guard let exitAfterSeconds else {
      return
    }
    exitTimer = Task { [weak self] in
      do {
        try await Task.sleep(for: .seconds(exitAfterSeconds))
      } catch {
        return  // Cancelled: the toy is already leaving.
      }
      self?.leave()
    }
  }

  /// The only way out: the exit combination or `--exit-after`.
  private func leave() {
    guard !isLeaving else {
      return
    }
    isLeaving = true
    exitTimer?.cancel()
    if let keyMonitor {
      NSEvent.removeMonitor(keyMonitor)
    }
    keyMonitor = nil
    soundPlayer?.stop()
    let app = NSApplication.shared
    app.presentationOptions = []
    NSCursor.unhide()
    app.terminate(nil)
  }
}
