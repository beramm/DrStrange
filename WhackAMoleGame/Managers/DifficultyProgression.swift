import Foundation

/// Moves the level up or down from recent accuracy on real targets (decoys are ignored).
/// Elapsed time alone never changes the level.
struct DifficultyProgression {
    let rules: AdaptiveDifficultyRules
    private(set) var level: DifficultyLevel
    private var recentOutcomes: [Bool] = []

    init(rules: AdaptiveDifficultyRules, startingLevel: DifficultyLevel) {
        self.rules = rules
        self.level = startingLevel
    }

    var recentAccuracy: Double? {
        recentOutcomes.isEmpty ? nil : Double(recentOutcomes.filter { $0 }.count) / Double(recentOutcomes.count)
    }

    /// Records one finished real target and returns the new level if it changed.
    mutating func record(hit: Bool) -> DifficultyLevel? {
        guard rules.isEnabled else { return nil }
        recentOutcomes.append(hit)
        if recentOutcomes.count > rules.evaluationWindow { recentOutcomes.removeFirst() }
        // Wait for a full window so one lucky or unlucky streak cannot change the level.
        guard recentOutcomes.count >= rules.evaluationWindow, let accuracy = recentAccuracy else { return nil }

        let newLevel: DifficultyLevel?
        if accuracy >= rules.promoteAccuracy {
            newLevel = level.next
        } else if accuracy <= rules.demoteAccuracy {
            newLevel = level.previous
        } else {
            newLevel = nil
        }
        guard let newLevel else { return nil }
        level = newLevel
        recentOutcomes.removeAll()
        return newLevel
    }
}
