/// The kind of visual a key press or a pointer makes.
public enum Element: Sendable, Equatable, CaseIterable {
  case fire
  case water
  case explosion
  case drop

  /// Shifting by 2 for each row makes a key differ from its neighbours at the left and the
  /// right, and from the key in the same column above and below. The order keeps Q as water
  /// and A as fire.
  private static let pattern: [Element] = [.explosion, .water, .drop, .fire]

  /// The pointer grid over the screen.
  private static let gridColumns = 12
  private static let gridRows = 6

  /// The effect of a key depends only on its place in the key map, so the same key always
  /// makes the same effect.
  public static func forKey(_ key: KeyInfo) -> Element {
    element(column: key.column, row: key.row)
  }

  /// The effect of a pointer place. `x` and `y` are 0…1, with y = 0 at the top.
  public static func at(x: Double, y: Double) -> Element {
    element(column: cell(x, count: gridColumns), row: cell(y, count: gridRows))
  }

  private static func element(column: Int, row: Int) -> Element {
    pattern[(column + 2 * row) % pattern.count]
  }

  private static func cell(_ value: Double, count: Int) -> Int {
    min(max(Int(value * Double(count)), 0), count - 1)
  }
}
