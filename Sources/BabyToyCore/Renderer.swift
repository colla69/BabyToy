import CoreGraphics
import CoreText
import Foundation

/// Draws a scene into a Core Graphics context. Pure: the same scene, time and size always
/// give the same picture, so the live view, the snapshot mode and the tests share it.
public enum Renderer {
  /// Whole multiples of 1/255, so an 8-bit bitmap holds this colour exactly.
  public static let backgroundColor = RGBColor(red: 18 / 255, green: 15 / 255, blue: 31 / 255)

  private static let labelColor = CGColor(srgbRed: 0.08, green: 0.07, blue: 0.14, alpha: 1)

  /// An 8-bit RGBA bitmap in sRGB. Its first row in memory is the top row of the image.
  public static func makeBitmapContext(width: Int, height: Int) -> CGContext? {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
      return nil
    }
    return CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
      space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  }

  public static func render(_ scene: Scene, at time: Double, into context: CGContext, size: CGSize)
  {
    context.saveGState()
    defer { context.restoreGState() }

    context.setFillColor(cgColor(backgroundColor))
    context.fill(CGRect(origin: .zero, size: size))

    let geometry = Geometry(size: size)
    var labels = LabelCache(fontSize: geometry.baseRadius * 1.1)
    for reaction in scene.reactions {
      let opacity = reaction.opacity(at: time)
      guard opacity > 0 else {
        continue
      }
      context.saveGState()
      context.setAlpha(opacity)
      context.translateBy(x: geometry.x(reaction.x), y: geometry.y(reaction.y))
      let scale = reaction.scale(at: time)
      context.scaleBy(x: scale, y: scale)
      drawShape(reaction, radius: geometry.baseRadius, in: context)
      if let label = reaction.label {
        drawLabel(labels.line(for: label), in: context)
      }
      context.restoreGState()
    }
  }

  /// Maps the scene's 0…1 coordinates, with y = 0 at the top, to the context's points,
  /// where y = 0 is the bottom. A margin keeps shapes at the edge on screen.
  private struct Geometry {
    let size: CGSize
    let marginX: CGFloat
    let marginY: CGFloat
    let baseRadius: CGFloat

    init(size: CGSize) {
      self.size = size
      marginX = size.width * 0.08
      marginY = size.height * 0.08
      baseRadius = min(size.width, size.height) * 0.06
    }

    func x(_ value: Double) -> CGFloat {
      marginX + CGFloat(value) * (size.width - 2 * marginX)
    }

    func y(_ value: Double) -> CGFloat {
      size.height - (marginY + CGFloat(value) * (size.height - 2 * marginY))
    }
  }

  /// One Core Text line per label character, built once per frame.
  private struct LabelCache {
    let font: CTFont
    var lines: [Character: CTLine] = [:]

    init(fontSize: CGFloat) {
      font =
        CTFontCreateUIFontForLanguage(.emphasizedSystem, fontSize, nil)
        ?? CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
    }

    mutating func line(for label: Character) -> CTLine {
      if let line = lines[label] {
        return line
      }
      let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): Renderer.labelColor,
      ]
      let text = NSAttributedString(string: String(label), attributes: attributes)
      let line = CTLineCreateWithAttributedString(text)
      lines[label] = line
      return line
    }
  }

  private static func drawShape(_ reaction: Reaction, radius: CGFloat, in context: CGContext) {
    let color = cgColor(reaction.color)
    switch reaction.shape {
    case .circle:
      context.setFillColor(color)
      context.fillEllipse(in: CGRect(x: -radius, y: -radius, width: 2 * radius, height: 2 * radius))
    case .star:
      context.setFillColor(color)
      context.addPath(starPath(outerRadius: radius * 1.2, innerRadius: radius * 0.55))
      context.fillPath()
    case .roundedSquare:
      let side = radius * 1.8
      let square = CGRect(x: -side / 2, y: -side / 2, width: side, height: side)
      context.setFillColor(color)
      context.addPath(
        CGPath(
          roundedRect: square, cornerWidth: radius * 0.4, cornerHeight: radius * 0.4,
          transform: nil))
      context.fillPath()
    case .ring:
      let lineWidth = radius * 0.3
      let inset = radius - lineWidth / 2
      context.setStrokeColor(color)
      context.setLineWidth(lineWidth)
      context.strokeEllipse(in: CGRect(x: -inset, y: -inset, width: 2 * inset, height: 2 * inset))
    }
  }

  private static func starPath(outerRadius: CGFloat, innerRadius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let points = 10
    for index in 0..<points {
      let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
      let angle = CGFloat.pi / 2 + CGFloat(index) * 2 * .pi / CGFloat(points)
      let point = CGPoint(x: radius * cos(angle), y: radius * sin(angle))
      if index == 0 {
        path.move(to: point)
      } else {
        path.addLine(to: point)
      }
    }
    path.closeSubpath()
    return path
  }

  /// Draws the line centred on the origin.
  private static func drawLabel(_ line: CTLine, in context: CGContext) {
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    context.textMatrix = .identity
    context.textPosition = CGPoint(x: -bounds.midX, y: -bounds.midY)
    CTLineDraw(line, context)
  }

  private static func cgColor(_ color: RGBColor) -> CGColor {
    CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1)
  }
}
