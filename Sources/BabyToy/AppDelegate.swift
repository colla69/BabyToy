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
  /// `BABYTOY_DEBUG=1` makes the toy describe on stderr what the key tap sees. Read once here.
  private let isDebug = ProcessInfo.processInfo.environment["BABYTOY_DEBUG"] == "1"
  private var window: KioskWindow?
  private var toyView: ToyView?
  private var soundPlayer: SoundPlayer?
  private var router = KeyRouter()
  private var keyTap: KeyTap?
  private var keyMonitor: Any?
  private var pointerRouter = PointerRouter()
  private var pointerMonitor: Any?
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
    startKeyTap()
    app.presentationOptions = Self.kioskOptions
    NSCursor.hide()
    startKeyMonitor()
    startPointerMonitor()
    startSound()
    startExitTimer()
    app.activate()
    if isDebug {
      printDebugStart()
    }
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

  /// From here until `leave()`, the tap takes every key before the system's hotkeys and
  /// top-row functions act, whichever app macOS says is in front, and routes it here.
  /// Without the tap the toy does not start.
  private func startKeyTap() {
    let keyTap = KeyTap(isDebug: isDebug) { [weak self] keyEvent in
      self?.handle(keyEvent)
    }
    guard keyTap.start() else {
      exitWithoutKeyTap("macOS refused the key tap, although the Accessibility permission is on.")
    }
    self.keyTap = keyTap
  }

  /// The fallback for keys while the key tap is off. It returns `nil`, so AppKit acts on no
  /// key at all: no shortcut, no menu, no beep.
  private func startKeyMonitor() {
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) {
      [weak self] event in
      MainActor.assumeIsolated {
        if let keyEvent = Self.keyEvent(from: event) {
          self?.handle(keyEvent)
        }
      }
      return nil
    }
  }

  /// The tap and the key monitor both route here, into the one `KeyRouter`.
  private func handle(_ keyEvent: KeyEvent) {
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

  /// The one place where mouse and trackpad events arrive. It returns `nil`, so AppKit acts
  /// on no click or scroll. The router in BabyToyCore makes every decision.
  private func startPointerMonitor() {
    let types: NSEvent.EventTypeMask = [
      .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
      .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel,
    ]
    pointerMonitor = NSEvent.addLocalMonitorForEvents(matching: types) { [weak self] event in
      MainActor.assumeIsolated {
        self?.handlePointer(event)
      }
      return nil
    }
  }

  private func handlePointer(_ event: NSEvent) {
    guard let pointerEvent = Self.pointerEvent(from: event), let toyView else {
      return
    }
    let response = pointerRouter.route(
      pointerEvent, at: CACurrentMediaTime(), screen: toyView.bounds.size)
    toyView.show(response)
    if let tone = response.tone {
      soundPlayer?.play(tone)
    }
  }

  private static func pointerEvent(from event: NSEvent) -> PointerEvent? {
    switch event.type {
    case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
      return .moved(dx: event.deltaX, dy: event.deltaY)
    case .scrollWheel:
      return .scrolled(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY)
    case .leftMouseDown, .rightMouseDown, .otherMouseDown:
      return .pressed
    default:
      return nil
    }
  }

  private func startSound() {
    soundPlayer = SoundPlayer()
    soundPlayer?.start()
  }

  /// The start lines of the debug switch. The tap no longer reads the active state, so macOS's
  /// view of it is information only. `activate()` may settle only after
  /// `applicationDidFinishLaunching` returns, so it is printed again after 1 s.
  private func printDebugStart() {
    Self.writeDebug(
      "BabyToy debug: key tap on, macOS reports the toy active \(NSApplication.shared.isActive)")
    Task {
      try? await Task.sleep(for: .seconds(1))
      Self.writeDebug(
        "BabyToy debug: after 1 s, macOS reports the toy active \(NSApplication.shared.isActive)")
    }
  }

  private static func writeDebug(_ line: String) {
    FileHandle.standardError.write(Data("\(line)\n".utf8))
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
    keyTap?.stop()
    keyTap = nil
    exitTimer?.cancel()
    if let keyMonitor {
      NSEvent.removeMonitor(keyMonitor)
    }
    keyMonitor = nil
    if let pointerMonitor {
      NSEvent.removeMonitor(pointerMonitor)
    }
    pointerMonitor = nil
    soundPlayer?.stop()
    let app = NSApplication.shared
    app.presentationOptions = []
    NSCursor.unhide()
    app.terminate(nil)
  }
}
