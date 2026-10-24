import BabyToyCore
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Runs scripted key presses and pointer events through the real scene, pointer router and
/// renderer, and writes the frames as PNG files. It opens no window, starts no app and plays
/// no sound, so it needs no macOS permission and is safe to run anywhere.
enum Snapshot {
  private enum Input {
    case key(UInt16)
    case pointer(PointerEvent)
  }

  private struct ScriptedInput {
    let time: Double
    let input: Input

    static func key(_ code: UInt16, at time: Double = 0) -> ScriptedInput {
      ScriptedInput(time: time, input: .key(code))
    }

    static func pointer(_ event: PointerEvent, at time: Double) -> ScriptedInput {
      ScriptedInput(time: time, input: .pointer(event))
    }
  }

  private struct Case {
    let name: String
    let inputs: [ScriptedInput]
  }

  private static let frameTimes = [0.1, 0.5, 1.4]
  /// The real screen of the user's Mac, in points.
  private static let width = 1728
  private static let height = 1117
  private static let screen = CGSize(width: width, height: height)
  private static let sceneSeed: UInt64 = 7

  /// (a) and (b) run first, so Core Graphics is warm before the timed frames of (c).
  private static let cases = [
    Case(name: "a", inputs: [.key(12)]),
    Case(name: "b", inputs: [12, 18, 3, 38, 44, 49, 35, 6, 111, 123].map { .key($0) }),
    Case(name: "c", inputs: (0..<300).map { .key(UInt16($0 % 50)) }),
    Case(name: "d", inputs: heldKeyWithRepeats(code: 38)),
    Case(name: "e", inputs: [12, 13, 14, 15].map { .key($0) }),
    Case(name: "f", inputs: (0..<100).map { .key(UInt16($0)) }),
    Case(name: "g", inputs: diagonalSwipe()),
  ]

  /// One press of J, then auto-repeat after 0.25 s, every 50 ms until the last frame.
  private static func heldKeyWithRepeats(code: UInt16) -> [ScriptedInput] {
    let repeats = stride(from: 0.25, through: 1.4, by: 0.05).map { ScriptedInput.key(code, at: $0) }
    return [.key(code)] + repeats
  }

  /// The pointer jumps from the centre to the bottom-left, then moves to the top-right over
  /// 1 s, every 16 ms, with one press at 0.5 s.
  private static func diagonalSwipe() -> [ScriptedInput] {
    let start = (x: 0.05, y: 0.95)
    let end = (x: 0.95, y: 0.05)
    let jump = ScriptedInput.pointer(
      .moved(dx: (start.x - 0.5) * Double(width), dy: (start.y - 0.5) * Double(height)), at: 0)
    let steps = Int(1.0 / 0.016)
    let stepX = (end.x - start.x) * Double(width) / Double(steps)
    let stepY = (end.y - start.y) * Double(height) / Double(steps)
    let moves = (1...steps).map { index in
      ScriptedInput.pointer(.moved(dx: stepX, dy: stepY), at: Double(index) * 0.016)
    }
    let press = ScriptedInput.pointer(.pressed, at: 0.5)
    return ([jump] + moves + [press]).sorted { $0.time < $1.time }
  }

  static func write(to directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var written = 0
    for snapshotCase in cases {
      let glides = play(snapshotCase, until: .infinity).glides
      if glides > 0 {
        print("\(snapshotCase.name): the pointer router asked for \(glides) glides")
      }
      for time in frameTimes {
        let fileName = "\(snapshotCase.name)-\(String(format: "%.1f", time)).png"
        let milliseconds = try writeFrame(
          of: snapshotCase, at: time, to: directory.appendingPathComponent(fileName))
        print("\(fileName)  render \(String(format: "%.2f", milliseconds)) ms")
        written += 1
      }
    }
    print("wrote \(written) PNG files to \(directory.path)")
  }

  /// Returns the render time in milliseconds, without the PNG encoding.
  private static func writeFrame(of snapshotCase: Case, at time: Double, to url: URL) throws
    -> Double
  {
    var scene = play(snapshotCase, until: time).scene
    scene.prune(at: time)

    guard let context = Renderer.makeBitmapContext(width: width, height: height) else {
      throw SnapshotError.cannotCreateBitmap(width: width, height: height)
    }
    let duration = ContinuousClock().measure {
      Renderer.render(scene, at: time, into: context, size: screen)
    }
    guard let image = context.makeImage() else {
      throw SnapshotError.cannotCreateBitmap(width: width, height: height)
    }
    try writePNG(image, to: url)
    let (seconds, attoseconds) = duration.components
    return Double(seconds) * 1000 + Double(attoseconds) / 1e15
  }

  /// Feeds the inputs up to `time` into a new scene, the way the app does, and counts the
  /// glides the pointer router asks for. Snapshot mode plays no sound.
  private static func play(_ snapshotCase: Case, until time: Double) -> (scene: Scene, glides: Int)
  {
    var scene = Scene(seed: sceneSeed)
    var router = PointerRouter()
    var glides = 0
    for scripted in snapshotCase.inputs where scripted.time <= time {
      switch scripted.input {
      case .key(let code):
        scene.press(keyCode: code, at: scripted.time)
      case .pointer(let event):
        let response = router.route(event, at: scripted.time, screen: screen)
        scene.apply(response, at: scripted.time)
        if case .glide = response.tone {
          glides += 1
        }
      }
    }
    return (scene, glides)
  }

  private static func writePNG(_ image: CGImage, to url: URL) throws {
    guard
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else {
      throw SnapshotError.cannotWrite(url)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw SnapshotError.cannotWrite(url)
    }
  }
}

enum SnapshotError: Error, CustomStringConvertible {
  case cannotCreateBitmap(width: Int, height: Int)
  case cannotWrite(URL)

  var description: String {
    switch self {
    case .cannotCreateBitmap(let width, let height):
      "could not create a \(width)x\(height) RGBA bitmap"
    case .cannotWrite(let url):
      "could not write the PNG file \(url.path). Check that the folder is writable."
    }
  }
}
