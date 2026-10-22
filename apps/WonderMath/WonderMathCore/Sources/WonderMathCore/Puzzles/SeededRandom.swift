import Foundation

/// Deterministic PRNG (SplitMix64) so puzzle generation is reproducible and
/// unit-testable. Each puzzle carries a seed derived from (topic, difficulty,
/// sequence number); the same seed always produces the same puzzle.
public struct SeededRandom: Sendable {
    public private(set) var state: UInt64

    public init(seed: UInt64) { state = seed }

    /// Combine arbitrary string/int inputs into a stable seed.
    public static func seed(_ parts: [CustomStringConvertible]) -> UInt64 {
        var h: UInt64 = 0x9E3779B97F4A7C15
        for part in parts {
            for b in String(describing: part).utf8 {
                h ^= UInt64(b)
                h &*= 0x100000001B3
                h ^= h >> 29
            }
            h ^= 0xA5
            h &*= 0x100000001B3
            h ^= h >> 29
        }
        return h
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform integer in `range`.
    public mutating func int(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    public mutating func element<T>(of array: [T]) -> T {
        array[int(in: 0...(array.count - 1))]
    }

    public mutating func probability(_ p: Double) -> Bool {
        Double(next() % 1_000_000) / 1_000_000.0 < p
    }

    public mutating func shuffled<T>(_ array: [T]) -> [T] {
        var a = array
        for i in stride(from: a.count - 1, through: 1, by: -1) {
            let j = int(in: 0...i)
            a.swapAt(i, j)
        }
        return a
    }
}
