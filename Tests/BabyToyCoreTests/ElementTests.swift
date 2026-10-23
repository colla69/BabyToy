import Testing

@testable import BabyToyCore

private func element(forCode code: UInt16) -> Element {
  Element.forKey(KeyboardLayout.key(for: code))
}

private let mappedCodes: [UInt16] = KeyboardLayout.mappedCodesByRow.flatMap { $0 } + [126]

@Suite("Effect per key")
struct ElementForKeyTests {
  @Test(
    "Named keys take the effect of the pattern",
    arguments: [
      (UInt16(12), Element.water), (0, .fire), (15, .explosion), (53, .explosion),
      (13, .drop), (49, .drop),
    ])
  func namedKeys(code: UInt16, expected: Element) {
    #expect(element(forCode: code) == expected)
  }

  @Test("In every row, keys side by side differ, and the row holds all four effects")
  func rowsAreMixed() {
    for row in KeyboardLayout.mappedCodesByRow {
      let elements = row.map { element(forCode: $0) }

      #expect(zip(elements, elements.dropFirst()).allSatisfy { $0 != $1 }, "\(row)")
      #expect(Set(elements) == Set(Element.allCases), "\(row)")
    }
  }

  @Test("Up and Down differ")
  func upAndDownDiffer() {
    #expect(element(forCode: 126) != element(forCode: 125))
  }

  @Test("Each effect has between 20% and 30% of the mapped keys")
  func effectsAreBalanced() {
    let elements = mappedCodes.map { element(forCode: $0) }

    #expect(mappedCodes.count == 77)
    for effect in Element.allCases {
      let share = Double(elements.filter { $0 == effect }.count) / Double(elements.count)
      #expect((0.2...0.3).contains(share), "\(effect): \(share)")
    }
  }

  @Test("An unmapped code gets an effect from its fallback place")
  func unmappedCodeGetsEffect() {
    let first = element(forCode: 200)

    #expect(Element.allCases.contains(first))
    #expect(element(forCode: 200) == first)
  }
}

@Suite("Effect per place")
struct ElementAtPlaceTests {
  private let columns = 12
  private let rows = 6

  private func center(column: Int, row: Int) -> (x: Double, y: Double) {
    ((Double(column) + 0.5) / Double(columns), (Double(row) + 0.5) / Double(rows))
  }

  @Test("Every point in one cell gives the same effect")
  func cellIsUniform() {
    let cellWidth = 1 / Double(columns)
    let cellHeight = 1 / Double(rows)
    let left = 3 * cellWidth
    let top = 2 * cellHeight
    let expected = Element.at(x: left + cellWidth / 2, y: top + cellHeight / 2)

    for fraction in [0.0, 0.25, 0.5, 0.75, 0.999] {
      let x = left + fraction * cellWidth
      let y = top + fraction * cellHeight
      #expect(Element.at(x: x, y: y) == expected, "\(fraction)")
    }
  }

  @Test("Cells side by side and above each other differ")
  func neighbouringCellsDiffer() {
    for row in 0..<rows {
      for column in 0..<columns {
        let here = center(column: column, row: row)
        let effect = Element.at(x: here.x, y: here.y)
        if column + 1 < columns {
          let right = center(column: column + 1, row: row)
          #expect(effect != Element.at(x: right.x, y: right.y), "\(column), \(row)")
        }
        if row + 1 < rows {
          let below = center(column: column, row: row + 1)
          #expect(effect != Element.at(x: below.x, y: below.y), "\(column), \(row)")
        }
      }
    }
  }

  @Test("Each grid row holds all four effects")
  func gridRowsHoldAllFour() {
    for row in 0..<rows {
      let effects = (0..<columns).map { column in
        let point = center(column: column, row: row)
        return Element.at(x: point.x, y: point.y)
      }
      #expect(Set(effects) == Set(Element.allCases), "row \(row)")
    }
  }

  @Test("The corners (0, 0) and (1, 1) give an effect")
  func cornersGiveEffect() {
    #expect(Element.allCases.contains(Element.at(x: 0, y: 0)))
    #expect(Element.allCases.contains(Element.at(x: 1, y: 1)))
  }
}
