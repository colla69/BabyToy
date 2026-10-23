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

  /// Every pixel that differs from the background, as (column, row).
  func painted() -> [(column: Int, row: Int)] {
    let background = backgroundBytes()
    return (0..<height).flatMap { row in
      (0..<width).compactMap { column in
        rgba(column: column, row: row) == background ? nil : (column, row)
      }
    }
  }

  /// The sums of each channel above the background, over the whole picture.
  func addedLight() -> (red: Int, green: Int, blue: Int) {
    let background = backgroundBytes()
    var sums = [0, 0, 0]
    for start in stride(from: 0, to: bytes.count, by: 4) {
      for channel in 0..<3 {
        sums[channel] += max(Int(bytes[start + channel]) - Int(background[channel]), 0)
      }
    }
    return (sums[0], sums[1], sums[2])
  }
}

private let size = CGSize(width: width, height: height)
private let unit = Double(min(width, height))

/// The reaction's place as (column, row) in the picture, with row 0 at the top.
private func place(of reaction: Reaction) -> (column: Double, row: Double) {
  let point = Renderer.Geometry(size: size).point(x: reaction.x, y: reaction.y)
  return (Double(point.x), Double(height) - Double(point.y))
}

private func centroid(_ pixels: [(column: Int, row: Int)]) -> (column: Double, row: Double) {
  let count = Double(pixels.count)
  return (
    Double(pixels.map(\.column).reduce(0, +)) / count,
    Double(pixels.map(\.row).reduce(0, +)) / count
  )
}

private func paintedWidth(_ pixels: [(column: Int, row: Int)]) -> Int {
  (pixels.map(\.column).max() ?? 0) - (pixels.map(\.column).min() ?? 0)
}

/// The centre of a pointer cell whose effect is `element`.
private func pointerPlace(of element: Element) -> (x: Double, y: Double)? {
  for row in 0..<6 {
    for column in 0..<12 {
      let x = (Double(column) + 0.5) / 12
      let y = (Double(row) + 0.5) / 6
      if Element.at(x: x, y: y) == element {
        return (x, y)
      }
    }
  }
  return nil
}

private func brightness(_ rgba: [UInt8]) -> Int {
  Int(rgba[0]) + Int(rgba[1]) + Int(rgba[2])
}

private let keyA: UInt16 = 0
private let keyQ: UInt16 = 12
private let keyW: UInt16 = 13
private let keyR: UInt16 = 15

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

  @Test("Fire is warm: A at 0.3 s adds more than twice as much red as blue")
  func fireIsWarm() throws {
    var scene = Scene()
    scene.press(keyCode: keyA, at: 0)

    let light = try rendered(scene, at: 0.3).addedLight()

    #expect(light.red > 2 * light.blue)
  }

  @Test("Water is cool: Q at 0.3 s adds more blue than red")
  func waterIsCool() throws {
    var scene = Scene()
    scene.press(keyCode: keyQ, at: 0)

    let light = try rendered(scene, at: 0.3).addedLight()

    #expect(light.blue > light.red)
  }

  @Test("Fire rises: A's topmost drawn row at 1.0 s is above its topmost row at 0.2 s")
  func fireRises() throws {
    var scene = Scene()
    scene.press(keyCode: keyA, at: 0)

    let early = try #require(try rendered(scene, at: 0.2).painted().map(\.row).min())
    let late = try #require(try rendered(scene, at: 1.0).painted().map(\.row).min())

    #expect(late < early)
  }

  @Test("An explosion flashes white at 0.05 s")
  func explosionFlashes() throws {
    var scene = Scene()
    scene.press(keyCode: keyR, at: 0)

    let pixels = try rendered(scene, at: 0.05)
    let colors = pixels.painted().map { pixels.rgba(column: $0.column, row: $0.row) }
    let brightest = try #require(colors.max { brightness($0) < brightness($1) })
    let center = place(of: try #require(scene.reactions.first))
    let atPlace = pixels.rgba(column: Int(center.column), row: Int(center.row))

    #expect(brightest.prefix(3).allSatisfy { $0 >= 200 }, "\(brightest)")
    // The sparks have left the place by 0.05 s, so only the flash lights it.
    #expect(atPlace.prefix(3).allSatisfy { $0 >= 200 }, "\(atPlace)")
  }

  @Test(
    "Only the newest 30 reactions get the flash",
    arguments: [(29, true), (30, false)])
  func extrasOnlyForNewest(newerTrails: Int, flashes: Bool) throws {
    var scene = Scene()
    scene.press(keyCode: keyR, at: 0)
    for _ in 0..<newerTrails {
      scene.trail(x: 0.95, y: 0.95, at: 0)
    }
    let center = place(of: try #require(scene.reactions.first))

    let pixels = try rendered(scene, at: 0.05)
    let atPlace = pixels.rgba(column: Int(center.column), row: Int(center.row))

    #expect(atPlace.prefix(3).allSatisfy { $0 >= 200 } == flashes, "\(atPlace)")
  }

  @Test("An explosion spreads past 0.08u to the left, right, top and bottom by 0.4 s")
  func explosionSpreads() throws {
    var scene = Scene()
    scene.press(keyCode: keyR, at: 0)
    let center = place(of: try #require(scene.reactions.first))
    let reach = 0.08 * unit

    let painted = try rendered(scene, at: 0.4).painted()

    #expect(painted.contains { Double($0.column) < center.column - reach })
    #expect(painted.contains { Double($0.column) > center.column + reach })
    #expect(painted.contains { Double($0.row) < center.row - reach })
    #expect(painted.contains { Double($0.row) > center.row + reach })
  }

  @Test("A drop falls, then spreads at its place")
  func dropFallsThenSpreads() throws {
    var scene = Scene()
    scene.press(keyCode: keyW, at: 0)
    let center = place(of: try #require(scene.reactions.first))

    let falling = try rendered(scene, at: 0.1).painted()
    let landed = try rendered(scene, at: 0.8).painted()
    let fallingCenter = centroid(falling)
    let landedCenter = centroid(landed)

    #expect(fallingCenter.row < center.row)
    #expect(abs(landedCenter.row - center.row) <= 0.02 * unit)
    #expect(abs(landedCenter.column - center.column) <= 0.02 * unit)
    #expect(landedCenter.row - fallingCenter.row >= 0.05 * unit)
    #expect(paintedWidth(landed) > paintedWidth(falling))
  }

  @Test("A trail paints fewer pixels than a burst", arguments: Element.allCases)
  func trailPaintsLess(element: Element) throws {
    let spot = try #require(pointerPlace(of: element))
    var burst = Scene()
    burst.burst(x: spot.x, y: spot.y, at: 0)
    var trail = Scene()
    trail.trail(x: spot.x, y: spot.y, at: 0)

    let burstCount = try rendered(burst, at: 0.5).painted().count
    let trailCount = try rendered(trail, at: 0.5).painted().count

    #expect(trailCount > 0 && trailCount < burstCount)
  }

  @Test("Two renders of equal scenes give identical bytes")
  func rendersAreDeterministic() throws {
    func scene() -> Scene {
      var scene = Scene(seed: 5)
      for code in UInt16(0)..<40 {
        scene.press(keyCode: code, at: Double(code) * 0.01)
      }
      scene.trail(x: 0.3, y: 0.3, at: 0.2)
      return scene
    }

    #expect(try rendered(scene(), at: 0.5).bytes == rendered(scene(), at: 0.5).bytes)
  }
}
