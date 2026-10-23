import CoreGraphics

/// One mouse or trackpad event as the app receives it. Deltas are in points, and a positive
/// `dy` means down, as in `NSEvent`.
public enum PointerEvent: Sendable, Equatable {
  /// A move or a drag.
  case moved(dx: Double, dy: Double)
  /// A two-finger scroll or a scroll wheel.
  case scrolled(dx: Double, dy: Double)
  /// Any button went down.
  case pressed
}

/// What the app does with one pointer event. Places are 0…1, with y = 0 at the top.
public enum PointerResponse: Sendable, Equatable {
  /// Draw a trail at the place, and play `glide` if there is one.
  case trail(x: Double, y: Double, glide: Tone?)
  /// Draw a burst at the place, and play `note`.
  case burst(x: Double, y: Double, note: Tone)
  case nothing
}

/// Moves a virtual pointer by the event deltas and decides what each event draws and plays.
/// The pointer starts at the centre and stays on the screen.
public struct PointerRouter: Sendable {
  /// At most 30 trail reactions per second, so a fast swipe cannot fill the scene.
  private static let trailInterval = 1.0 / 30
  /// The soft notes of a moving pointer come at most this often…
  private static let glideInterval = 0.15
  /// …and only after the pointer travelled this part of the screen width, so a jiggle
  /// stays quiet.
  private static let glideDistance = 0.03
  /// Absorbs rounding, so a move of exactly the limit counts.
  private static let tolerance = 1e-9

  private var x = 0.5
  private var y = 0.5
  private var lastTrailTime = -Double.infinity
  private var lastGlideTime = -Double.infinity
  private var lastGlideX = 0.5
  private var lastGlideY = 0.5

  public init() {}

  public mutating func route(_ event: PointerEvent, at time: Double, screen: CGSize)
    -> PointerResponse
  {
    switch event {
    case .pressed:
      return .burst(x: x, y: y, note: Tones.tone(forPointerX: x))
    case .moved(let dx, let dy), .scrolled(let dx, let dy):
      move(dx: dx, dy: dy, screen: screen)
      return trail(at: time, screen: screen)
    }
  }

  private mutating func move(dx: Double, dy: Double, screen: CGSize) {
    guard screen.width > 0, screen.height > 0 else {
      return
    }
    x = min(max(x + dx / Double(screen.width), 0), 1)
    y = min(max(y + dy / Double(screen.height), 0), 1)
  }

  private mutating func trail(at time: Double, screen: CGSize) -> PointerResponse {
    guard time - lastTrailTime >= Self.trailInterval - Self.tolerance else {
      return .nothing
    }
    lastTrailTime = time
    guard shouldGlide(at: time, screen: screen) else {
      return .trail(x: x, y: y, glide: nil)
    }
    lastGlideTime = time
    lastGlideX = x
    lastGlideY = y
    return .trail(x: x, y: y, glide: Tones.glide(forPointerX: x))
  }

  private func shouldGlide(at time: Double, screen: CGSize) -> Bool {
    let width = Double(screen.width)
    let dx = (x - lastGlideX) * width
    let dy = (y - lastGlideY) * Double(screen.height)
    let travelled = (dx * dx + dy * dy).squareRoot()
    return time - lastGlideTime >= Self.glideInterval - Self.tolerance
      && travelled >= Self.glideDistance * width - Self.tolerance
  }
}
