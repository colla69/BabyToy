import CoreGraphics
import Testing

@testable import BabyToyCore

private let width = 400
private let height = 300

/// An RGBA picture read back from a bitmap. Row 0 is the top of the image, as a PNG of it
/// shows it.
private struct Pixels {
  let bytes: [UInt8]

  func rgba(column: Int, row: Int) -> [UInt8] {
    let start = (row * width + column) * 4
    return Array(bytes[start..<start + 4])
  }

  /// Whether any pixel in the given quarter differs from `background`.
  func hasDrawing(columns: Range<Int>, rows: Range<Int>, background: [UInt8]) -> Bool {
    rows.contains { row in
      columns.contains { column in rgba(column: column, row: row) != background }
    }
  }
}

private func rendered(_ scene: Scene, at time: Double) throws -> Pixels {
  let context = try #require(Renderer.makeBitmapContext(width: width, height: height))
  Renderer.render(scene, at: time, into: context, size: CGSize(width: width, height: height))
  let data = try #require(context.data)
  let buffer = UnsafeBufferPointer(
    start: data.assumingMemoryBound(to: UInt8.self), count: width * height * 4)
  return Pixels(bytes: Array(buffer))
}

private func backgroundBytes() -> [UInt8] {
  let color = Renderer.backgroundColor
  return [color.red, color.green, color.blue].map { UInt8(($0 * 255).rounded()) } + [255]
}

private let topLeft = (columns: 0..<width / 2, rows: 0..<height / 2)
private let bottomRight = (columns: width / 2..<width, rows: height / 2..<height)

@Suite("Renderer")
struct RendererTests {
  @Test("An empty scene is all background colour")
  func emptySceneIsBackground() throws {
    let pixels = try rendered(Scene(), at: 0)
    let background = backgroundBytes()

    let differing = stride(from: 0, to: pixels.bytes.count, by: 4).filter {
      Array(pixels.bytes[$0..<$0 + 4]) != background
    }

    #expect(differing.isEmpty)
  }

  @Test("A reaction for Q draws in the top-left quarter and not in the bottom-right")
  func qDrawsTopLeft() throws {
    var scene = Scene()
    scene.press(keyCode: 12, at: 0)

    let pixels = try rendered(scene, at: 0.5)
    let background = backgroundBytes()

    #expect(
      pixels.hasDrawing(columns: topLeft.columns, rows: topLeft.rows, background: background))
    #expect(
      !pixels.hasDrawing(
        columns: bottomRight.columns, rows: bottomRight.rows, background: background))
  }

  @Test("A reaction for Slash draws in the bottom-right quarter and not in the top-left")
  func slashDrawsBottomRight() throws {
    var scene = Scene()
    scene.press(keyCode: 44, at: 0)

    let pixels = try rendered(scene, at: 0.5)
    let background = backgroundBytes()

    #expect(
      pixels.hasDrawing(
        columns: bottomRight.columns, rows: bottomRight.rows, background: background))
    #expect(
      !pixels.hasDrawing(columns: topLeft.columns, rows: topLeft.rows, background: background))
  }

  @Test("A reaction past its lifetime draws nothing")
  func expiredReactionIsInvisible() throws {
    var scene = Scene()
    scene.press(keyCode: 12, at: 0)

    let pixels = try rendered(scene, at: Scene.lifetime)

    #expect(
      !pixels.hasDrawing(columns: 0..<width, rows: 0..<height, background: backgroundBytes()))
  }
}
