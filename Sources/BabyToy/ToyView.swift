import AppKit
import BabyToyCore
import QuartzCore

/// Shows the scene. Each display-link tick sends a copy of the scene to a background queue,
/// which renders it into an image. The main thread only sets that image as the layer's
/// contents, so a slow frame never blocks key handling or the exit combination.
@MainActor
final class ToyView: NSView {
  private var scene = Scene(seed: UInt64.random(in: .min ... .max))
  private let renderQueue = DispatchQueue(label: "BabyToy.render", qos: .userInteractive)
  private var isRendering = false
  private var displayLink: CADisplayLink?

  override init(frame: NSRect) {
    super.init(frame: frame)
    wantsLayer = true
    layer?.contentsGravity = .resize
    let background = Renderer.backgroundColor
    layer?.backgroundColor = CGColor(
      srgbRed: background.red, green: background.green, blue: background.blue, alpha: 1)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("ToyView is built in code, not from a nib")
  }

  /// Seconds on the clock that both key presses and frames use.
  private var now: Double { CACurrentMediaTime() }

  func press(keyCode: UInt16) {
    scene.press(keyCode: keyCode, at: now)
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard window != nil, displayLink == nil else {
      return
    }
    let link = displayLink(target: self, selector: #selector(tick(_:)))
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  @objc private func tick(_ link: CADisplayLink) {
    guard !isRendering else {
      return
    }
    let time = now
    scene.prune(at: time)
    let frameScene = scene
    let size = bounds.size
    isRendering = true
    renderQueue.async { [weak self] in
      let image = Self.renderFrame(frameScene, at: time, size: size)
      Task { @MainActor [weak self] in
        self?.show(image)
      }
    }
  }

  private func show(_ image: CGImage?) {
    isRendering = false
    if let image {
      layer?.contents = image
    }
  }

  /// Runs on the render queue. Frames render at point resolution, as the plan says.
  private nonisolated static func renderFrame(_ scene: Scene, at time: Double, size: CGSize)
    -> CGImage?
  {
    let width = Int(size.width.rounded())
    let height = Int(size.height.rounded())
    guard width > 0, height > 0,
      let context = Renderer.makeBitmapContext(width: width, height: height)
    else {
      return nil
    }
    Renderer.render(scene, at: time, into: context, size: CGSize(width: width, height: height))
    return context.makeImage()
  }
}
