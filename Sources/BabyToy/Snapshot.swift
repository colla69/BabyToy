import BabyToyCore
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Runs scripted key presses through the real scene and renderer and writes the frames as
/// PNG files. It opens no window, starts no app and plays no sound, so it needs no macOS
/// permission and is safe to run anywhere.
enum Snapshot {
  private struct KeyPress {
    let time: Double
    let code: UInt16
  }

  private struct Case {
    let name: String
    let presses: [KeyPress]
  }

  private static let frameTimes = [0.1, 0.5, 1.4]
  private static let width = 1280
  private static let height = 800
  private static let sceneSeed: UInt64 = 7

  /// (a) and (b) run first, so the font is loaded before the timed frames of (c).
  private static let cases = [
    Case(name: "a", presses: [KeyPress(time: 0, code: 12)]),
    Case(
      name: "b",
      presses: [12, 18, 3, 38, 44, 49, 35, 6, 111, 123].map { KeyPress(time: 0, code: $0) }),
    Case(name: "c", presses: (0..<300).map { KeyPress(time: 0, code: UInt16($0 % 50)) }),
    Case(name: "d", presses: heldKeyWithRepeats(code: 38)),
  ]

  /// One press of J, then auto-repeat after 0.25 s, every 50 ms until the last frame.
  private static func heldKeyWithRepeats(code: UInt16) -> [KeyPress] {
    let repeats = stride(from: 0.25, through: 1.4, by: 0.05).map { KeyPress(time: $0, code: code) }
    return [KeyPress(time: 0, code: code)] + repeats
  }

  static func write(to directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var written = 0
    for snapshotCase in cases {
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
    var scene = Scene(seed: sceneSeed)
    for press in snapshotCase.presses where press.time <= time {
      scene.press(keyCode: press.code, at: press.time)
    }
    scene.prune(at: time)

    guard let context = Renderer.makeBitmapContext(width: width, height: height) else {
      throw SnapshotError.cannotCreateBitmap(width: width, height: height)
    }
    let size = CGSize(width: width, height: height)
    let duration = ContinuousClock().measure {
      Renderer.render(scene, at: time, into: context, size: size)
    }
    guard let image = context.makeImage() else {
      throw SnapshotError.cannotCreateBitmap(width: width, height: height)
    }
    try writePNG(image, to: url)
    let (seconds, attoseconds) = duration.components
    return Double(seconds) * 1000 + Double(attoseconds) / 1e15
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
