import Foundation

/// Small seedable generator (SplitMix64) so a session can be replayed exactly from its seed.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Draws every element once (in random order) before any element repeats.
/// Used wherever balance matters more than independence: character looks and eye assignment.
struct ShuffleBag<Element: Equatable> {
    private let contents: [Element]
    private var remaining: [Element] = []
    private var lastDrawn: Element?

    init(_ contents: [Element]) {
        precondition(!contents.isEmpty, "ShuffleBag needs at least one element")
        self.contents = contents
    }

    mutating func next(using generator: inout some RandomNumberGenerator) -> Element {
        if remaining.isEmpty {
            remaining = contents.shuffled(using: &generator)
            // Avoid the same element twice in a row across a refill.
            if remaining.count > 1, remaining.last == lastDrawn,
               let swapIndex = remaining.indices.dropLast().randomElement(using: &generator) {
                remaining.swapAt(swapIndex, remaining.count - 1)
            }
        }
        let element = remaining.removeLast()
        lastDrawn = element
        return element
    }
}
