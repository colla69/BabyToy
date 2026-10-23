/// Where a key sits on the keyboard and what kind of key it is.
public struct KeyInfo: Sendable, Equatable {
  /// 0 is the left edge of the keyboard, 1 the right edge.
  public let x: Double
  /// 0 is the top row of the keyboard, 1 the bottom row.
  public let y: Double
  public let group: KeyGroup
  /// The row index, 0 for the function row to 5 for the Space row.
  let row: Int
  /// The key's index in its row, 0 at the left.
  let column: Int
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

    init(_ code: UInt16, _ width: Double = 1, _ group: KeyGroup = .other) {
      self.code = code
      self.width = width
      self.group = group
    }

    static func letter(_ code: UInt16) -> PhysicalKey {
      PhysicalKey(code, 1, .letter)
    }

    static func digit(_ code: UInt16) -> PhysicalKey {
      PhysicalKey(code, 1, .digit)
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
      PhysicalKey(50), .digit(18), .digit(19), .digit(20), .digit(21),
      .digit(23), .digit(22), .digit(26), .digit(28), .digit(25),
      .digit(29), PhysicalKey(27), PhysicalKey(24), PhysicalKey(51, 1.5, .bigKey),
    ],
    [
      PhysicalKey(48, 1.5), .letter(12), .letter(13), .letter(14),
      .letter(15), .letter(17), .letter(16), .letter(32), .letter(34),
      .letter(31), .letter(35), PhysicalKey(33), PhysicalKey(30), PhysicalKey(42),
    ],
    [
      PhysicalKey(57, 1.75), .letter(0), .letter(1), .letter(2), .letter(3),
      .letter(5), .letter(4), .letter(38), .letter(40), .letter(37),
      PhysicalKey(41), PhysicalKey(39), PhysicalKey(36, 1.75, .bigKey),
    ],
    [
      PhysicalKey(56, 2.25), .letter(6), .letter(7), .letter(8), .letter(9),
      .letter(11), .letter(45), .letter(46), PhysicalKey(43), PhysicalKey(47),
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
      for (columnIndex, key) in row.enumerated() {
        let x = (left + key.width / 2) / rowWidth
        keys[key.code] = KeyInfo(
          x: x, y: Double(rowIndex) / lastRow, group: key.group, row: rowIndex,
          column: columnIndex)
        left += key.width
      }
    }
    // Up takes row 4, so it differs from Down in effect as well as in place.
    if let down = keys[downArrow] {
      keys[upArrow] = KeyInfo(
        x: down.x, y: down.y - 0.5 / lastRow, group: .other, row: down.row - 1,
        column: down.column)
    }
    return keys
  }()

  /// The codes of the key map, row by row from the top, each row from the left. Up is not
  /// in a row of its own.
  static let mappedCodesByRow: [[UInt16]] = rows.map { row in row.map(\.code) }

  /// Keys outside the map, such as the keypad or keys of other keyboards, still get a
  /// position. Spreading them by code keeps them from all landing on one spot.
  private static func fallbackKey(for code: UInt16) -> KeyInfo {
    let columns = 13
    let rowCount = 5
    let column = Int(code) % columns
    let row = Int(code) / columns % rowCount
    let x = Double(column) / Double(columns - 1)
    let y = Double(row) / Double(rowCount - 1)
    return KeyInfo(x: x, y: y, group: .other, row: row, column: column)
  }
}
