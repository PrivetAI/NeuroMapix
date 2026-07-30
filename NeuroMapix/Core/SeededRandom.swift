import Foundation

/// Deterministic xorshift64 generator. Every board in the app is produced from an
/// explicit seed so a layout can be reproduced exactly (and validated offline).
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func nextRaw() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    /// Uniform value in 0..<bound.
    mutating func int(_ bound: Int) -> Int {
        guard bound > 0 else { return 0 }
        return Int(nextRaw() % UInt64(bound))
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        let span = range.upperBound - range.lowerBound + 1
        return range.lowerBound + int(span)
    }

    mutating func double() -> Double {
        Double(nextRaw() % 1_000_000) / 1_000_000.0
    }

    mutating func bool() -> Bool { nextRaw() % 2 == 0 }

    mutating func pick<T>(_ items: [T]) -> T {
        items[int(items.count)]
    }

    mutating func shuffled<T>(_ items: [T]) -> [T] {
        var copy = items
        guard copy.count > 1 else { return copy }
        for i in stride(from: copy.count - 1, to: 0, by: -1) {
            let j = int(i + 1)
            copy.swapAt(i, j)
        }
        return copy
    }

    /// Distinct sample of `count` elements (or as many as exist).
    mutating func sample<T>(_ items: [T], _ count: Int) -> [T] {
        Array(shuffled(items).prefix(max(0, count)))
    }

    static func mix(_ values: [UInt64]) -> UInt64 {
        var h: UInt64 = 0xCBF29CE484222325
        for v in values {
            h = (h ^ v) &* 0x100000001B3
        }
        return h
    }
}
