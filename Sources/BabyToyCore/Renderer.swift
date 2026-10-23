import CoreGraphics

/// Draws a scene into a Core Graphics context. Pure: the same scene, time and size always
/// give the same picture, so the live view, the snapshot mode and the tests share it.
public enum Renderer {
  /// Whole multiples of 1/255, so an 8-bit bitmap holds this colour exactly.
  public static let backgroundColor = RGBColor(red: 18 / 255, green: 15 / 255, blue: 31 / 255)

  /// Glows and flashes paint large areas, and painted area is what a frame costs. Only the
  /// newest reactions get them.
  static let extrasLimit = 30

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

    context.setFillColor(cgColor(backgroundColor, alpha: 1))
    context.fill(CGRect(origin: .zero, size: size))

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
      return
    }
    let geometry = Geometry(size: size)
    let live = scene.reactions.filter { time - $0.spawnTime < Scene.lifetime }
    let detail = Particles.detail(forLiveCount: live.count)
    let firstWithExtras = live.count - extrasLimit
    for (index, reaction) in live.enumerated() {
      let place = geometry.point(x: reaction.x, y: reaction.y)
      if index >= firstWithExtras {
        for particle in Particles.extras(for: reaction, at: time) {
          draw(particle, at: place, unit: geometry.unit, colorSpace: colorSpace, in: context)
        }
      }
      for particle in Particles.particles(for: reaction, at: time, detail: detail) {
        draw(particle, at: place, unit: geometry.unit, colorSpace: colorSpace, in: context)
      }
    }
  }

  /// Maps the scene's 0…1 coordinates, with y = 0 at the top, to the context's points,
  /// where y = 0 is the bottom. A margin keeps reactions at the edge on screen.
  struct Geometry {
    let size: CGSize
    let marginX: CGFloat
    let marginY: CGFloat
    /// The short side, the unit u of every particle size.
    let unit: CGFloat

    init(size: CGSize) {
      self.size = size
      marginX = size.width * 0.08
      marginY = size.height * 0.08
      unit = min(size.width, size.height)
    }

    func point(x: Double, y: Double) -> CGPoint {
      CGPoint(
        x: marginX + CGFloat(x) * (size.width - 2 * marginX),
        y: size.height - (marginY + CGFloat(y) * (size.height - 2 * marginY)))
    }
  }

  private static func draw(
    _ particle: Particle, at place: CGPoint, unit: CGFloat, colorSpace: CGColorSpace,
    in context: CGContext
  ) {
    guard particle.alpha > 0 else {
      return
    }
    // Particle offsets point down, the context's y points up.
    let center = CGPoint(
      x: place.x + CGFloat(particle.x) * unit, y: place.y - CGFloat(particle.y) * unit)
    let radius = CGFloat(particle.radius) * unit
    context.setBlendMode(particle.blend == .additive ? .plusLighter : .normal)
    switch particle.kind {
    case .glowDot:
      guard let gradient = glow(particle.color, alpha: particle.alpha, colorSpace: colorSpace)
      else {
        return
      }
      context.drawRadialGradient(
        gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius,
        options: [])
    case .filledDot:
      context.setFillColor(cgColor(particle.color, alpha: particle.alpha))
      context.fillEllipse(
        in: CGRect(
          x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
    case .ring(let heightRatio, let lineWidth):
      let ringHeight = radius * CGFloat(heightRatio)
      context.setStrokeColor(cgColor(particle.color, alpha: particle.alpha))
      context.setLineWidth(CGFloat(lineWidth) * unit)
      context.strokeEllipse(
        in: CGRect(
          x: center.x - radius, y: center.y - ringHeight, width: 2 * radius,
          height: 2 * ringHeight))
    }
  }

  /// Full colour at the centre, half at 45% of the radius, clear at the edge.
  private static func glow(_ color: RGBColor, alpha: Double, colorSpace: CGColorSpace)
    -> CGGradient?
  {
    let (red, green, blue) = (CGFloat(color.red), CGFloat(color.green), CGFloat(color.blue))
    let opacity = CGFloat(alpha)
    let components: [CGFloat] = [
      red, green, blue, opacity,
      red, green, blue, opacity * 0.5,
      red, green, blue, 0,
    ]
    let locations: [CGFloat] = [0, 0.45, 1]
    return CGGradient(
      colorSpace: colorSpace, colorComponents: components, locations: locations,
      count: locations.count)
  }

  private static func cgColor(_ color: RGBColor, alpha: Double) -> CGColor {
    CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: alpha)
  }
}
