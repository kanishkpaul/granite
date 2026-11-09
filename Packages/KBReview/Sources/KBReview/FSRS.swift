import Foundation

/// How well you recalled a prompt.
public enum Grade: Int, Sendable, Codable, CaseIterable {
    case again = 1, hard, good, easy
}

/// A prompt's memory state.
public struct CardState: Sendable, Equatable, Codable {
    /// Days until recall probability falls to 90%.
    public var stability: Double
    /// 1 (easy) … 10 (hard).
    public var difficulty: Double
    public var lastReview: Date
    public var due: Date
    public var reviews: Int
    public var lapses: Int
}

/// FSRS-5 (Free Spaced Repetition Scheduler) with its published default parameters. It beat
/// trainable SM-2 in 97.4% of collections on a ~729M-review benchmark (master plan §7, idea 6).
public struct FSRS: Sendable {
    public static let defaultWeights: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, 0.1192, 1.01925,
        1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621,
    ]
    static let decay = -0.5
    static let factor = 19.0 / 81.0

    public let w: [Double]
    /// Target probability of recall at the due date.
    public let retention: Double
    public let maximumInterval: Double

    public init(weights: [Double] = FSRS.defaultWeights, retention: Double = 0.9, maximumInterval: Double = 36_500) {
        precondition(weights.count == 19, "FSRS-5 has 19 parameters")
        w = weights
        self.retention = retention
        self.maximumInterval = maximumInterval
    }

    /// Probability of recall after `days` with stability `stability`.
    public func retrievability(days: Double, stability: Double) -> Double {
        pow(1 + Self.factor * days / stability, Self.decay)
    }

    /// Days until recall probability falls to `retention`.
    public func interval(stability: Double) -> Double {
        let days = stability / Self.factor * (pow(retention, 1 / Self.decay) - 1)
        return min(maximumInterval, max(1, days.rounded()))
    }

    func initialStability(_ grade: Grade) -> Double { max(0.1, w[grade.rawValue - 1]) }

    func initialDifficulty(_ grade: Grade) -> Double {
        clampDifficulty(w[4] - exp(w[5] * Double(grade.rawValue - 1)) + 1)
    }

    func clampDifficulty(_ value: Double) -> Double { min(10, max(1, value)) }

    func nextDifficulty(_ difficulty: Double, grade: Grade) -> Double {
        let delta = -w[6] * Double(grade.rawValue - 3)
        let damped = difficulty + delta * (10 - difficulty) / 9
        // Mean reversion toward the difficulty of a first "easy".
        return clampDifficulty(w[7] * initialDifficulty(.easy) + (1 - w[7]) * damped)
    }

    func stabilityAfterSuccess(_ s: Double, difficulty d: Double, retrievability r: Double, grade: Grade) -> Double {
        let hard = grade == .hard ? w[15] : 1
        let easy = grade == .easy ? w[16] : 1
        return s * (exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp(w[10] * (1 - r)) - 1) * hard * easy + 1)
    }

    func stabilityAfterLapse(_ s: Double, difficulty d: Double, retrievability r: Double) -> Double {
        let next = w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp(w[14] * (1 - r))
        return min(next, s)
    }

    func shortTermStability(_ s: Double, grade: Grade) -> Double {
        s * exp(w[17] * (Double(grade.rawValue - 3) + w[18]))
    }

    /// The state after reviewing `card` (nil for a new prompt) with `grade` at `now`.
    public func review(_ card: CardState?, grade: Grade, now: Date) -> CardState {
        guard let card else {
            let stability = initialStability(grade)
            return CardState(stability: stability, difficulty: initialDifficulty(grade), lastReview: now,
                             due: now.addingTimeInterval(grade == .again ? 600 : interval(stability: stability) * 86_400),
                             reviews: 1, lapses: grade == .again ? 1 : 0)
        }
        let days = max(0, now.timeIntervalSince(card.lastReview) / 86_400)
        let r = retrievability(days: days, stability: card.stability)
        let stability: Double
        if days < 1 {
            stability = shortTermStability(card.stability, grade: grade)
        } else if grade == .again {
            stability = stabilityAfterLapse(card.stability, difficulty: card.difficulty, retrievability: r)
        } else {
            stability = stabilityAfterSuccess(card.stability, difficulty: card.difficulty, retrievability: r, grade: grade)
        }
        let next = max(0.1, stability)
        // A lapse comes back in ten minutes; everything else at the target retention.
        let due = grade == .again ? now.addingTimeInterval(600) : now.addingTimeInterval(interval(stability: next) * 86_400)
        return CardState(stability: next, difficulty: nextDifficulty(card.difficulty, grade: grade), lastReview: now, due: due,
                         reviews: card.reviews + 1, lapses: card.lapses + (grade == .again ? 1 : 0))
    }
}
