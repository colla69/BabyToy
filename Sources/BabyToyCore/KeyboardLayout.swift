/// Where a key sits on the keyboard, what kind of key it is, and what it shows.
public struct KeyInfo: Sendable, Equatable {
  /// 0 is the left edge of the keyboard, 1 the right edge.
  public let x: Double
  /// 0 is the top row of the keyboard, 1 the bottom row.
  public let y: Double
  public let group: KeyGroup
  public let label: Character?

  public init(x: Double, y: Double, group: KeyGroup, label: Character?) {
    self.x = x
    self.y = y
    self.group = group
    self.label = label
  }
}

public enum KeyGroup: Sendable, Equatable, CaseIterable {
  case letter
  case digit
  /// Space, Return and Delete.
  case bigKey
  /// Modifiers, arrows, function keys and the rest.
  case other
}

/// Maps a macOS virtual key code (`NSEvent.keyCode`) to its place on a US ANSI Mac keyboard.
///
/// Key codes name the physical key, not the character, so the map holds for every keyboard
/// layout. Codes are from `HIToolbox/Events.h`.
public enum KeyboardLayout {
  public static func key(for code: UInt16) -> KeyInfo {
    if let known = keysByCode[code] {
      return known
    }
    return fallbackKey(for: code)
  }

  private struct PhysicalKey {
    let code: UInt16
    let width: Double
    let group: KeyGroup
    let label: Character?

    init(_ code: UInt16, _ width: Double = 1, _ group: KeyGroup = .other, _ label: Character? = nil)
    {
      self.code = code
      self.width = width
      self.group = group
      self.label = label
    }

    static func letter(_ code: UInt16, _ label: Character) -> PhysicalKey {
      PhysicalKey(code, 1, .letter, label)
    }

    static func digit(_ code: UInt16, _ label: Character) -> PhysicalKey {
      PhysicalKey(code, 1, .digit, label)
    }
  }

  /// The rows from top to bottom, each key with its width in key units.
  private static let rows: [[PhysicalKey]] = [
    [
      PhysicalKey(53), PhysicalKey(122), PhysicalKey(120), PhysicalKey(99), PhysicalKey(118),
      PhysicalKey(96), PhysicalKey(97), PhysicalKey(98), PhysicalKey(100), PhysicalKey(101),
      PhysicalKey(109), PhysicalKey(103), PhysicalKey(111),
    ],
    [
      PhysicalKey(50), .digit(18, "1"), .digit(19, "2"), .digit(20, "3"), .digit(21, "4"),
      .digit(23, "5"), .digit(22, "6"), .digit(26, "7"), .digit(28, "8"), .digit(25, "9"),
      .digit(29, "0"), PhysicalKey(27), PhysicalKey(24), PhysicalKey(51, 1.5, .bigKey),
    ],
    [
      PhysicalKey(48, 1.5), .letter(12, "Q"), .letter(13, "W"), .letter(14, "E"),
      .letter(15, "R"), .letter(17, "T"), .letter(16, "Y"), .letter(32, "U"), .letter(34, "I"),
      .letter(31, "O"), .letter(35, "P"), PhysicalKey(33), PhysicalKey(30), PhysicalKey(42),
    ],
    [
      PhysicalKey(57, 1.75), .letter(0, "A"), .letter(1, "S"), .letter(2, "D"), .letter(3, "F"),
      .letter(5, "G"), .letter(4, "H"), .letter(38, "J"), .letter(40, "K"), .letter(37, "L"),
      PhysicalKey(41), PhysicalKey(39), PhysicalKey(36, 1.75, .bigKey),
    ],
    [
      PhysicalKey(56, 2.25), .letter(6, "Z"), .letter(7, "X"), .letter(8, "C"), .letter(9, "V"),
      .letter(11, "B"), .letter(45, "N"), .letter(46, "M"), PhysicalKey(43), PhysicalKey(47),
      PhysicalKey(44), PhysicalKey(60, 2.25),
    ],
    [
      PhysicalKey(63), PhysicalKey(59), PhysicalKey(58), PhysicalKey(55, 1.25),
      PhysicalKey(49, 5, .bigKey), PhysicalKey(54, 1.25), PhysicalKey(61), PhysicalKey(123),
      PhysicalKey(125), PhysicalKey(124),
    ],
  ]

  /// Up shares the column of Down, half a row higher.
  private static let upArrow: UInt16 = 126
  private static let downArrow: UInt16 = 125

  private static let keysByCode: [UInt16: KeyInfo] = {
    var keys: [UInt16: KeyInfo] = [:]
    let lastRow = Double(rows.count - 1)
    for (rowIndex, row) in rows.enumerated() {
      let rowWidth = row.reduce(0) { $0 + $1.width }
      var left = 0.0
      for key in row {
        let x = (left + key.width / 2) / rowWidth
        keys[key.code] = KeyInfo(
          x: x, y: Double(rowIndex) / lastRow, group: key.group, label: key.label)
        left += key.width
      }
    }
    if let down = keys[downArrow] {
      keys[upArrow] = KeyInfo(x: down.x, y: down.y - 0.5 / lastRow, group: .other, label: nil)
    }
    return keys
  }()

  /// Keys outside the map, such as the keypad or keys of other keyboards, still get a
  /// position. Spreading them by code keeps them from all landing on one spot.
  private static func fallbackKey(for code: UInt16) -> KeyInfo {
    let columns = 13
    let rowCount = 5
    let x = Double(Int(code) % columns) / Double(columns - 1)
    let y = Double(Int(code) / columns % rowCount) / Double(rowCount - 1)
    return KeyInfo(x: x, y: y, group: .other, label: nil)
  }
}
