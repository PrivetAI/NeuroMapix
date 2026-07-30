import Foundation

/// What the player has to produce for one stage.
struct Solution {
    /// Ordered when `orderMatters`, otherwise treated as a set.
    var required: [Coord] = []
    var orderMatters: Bool = false
    /// coord -> correct raw attribute value (paint stages only).
    var paint: [Coord: Int] = [:]
    /// Cells that carry a heavier penalty when selected.
    var traps: Set<Coord> = []
    var extraWeight: Double = 1.0
    var trapWeight: Double = 2.0

    var totalElements: Int { paint.isEmpty ? required.count : paint.count }
    var requiredSet: Set<Coord> { paint.isEmpty ? Set(required) : Set(paint.keys) }
}

/// What the player actually produced for one stage.
struct StageAnswer {
    var cells: [Coord] = []
    var paint: [Coord: Int] = [:]

    static func cells(_ list: [Coord]) -> StageAnswer { StageAnswer(cells: list, paint: [:]) }
    static func painted(_ map: [Coord: Int]) -> StageAnswer { StageAnswer(cells: [], paint: map) }
}

struct Grade {
    var correct: Double
    var penalty: Double
    var total: Int

    var net: Double { max(0, correct - penalty) }
    var accuracy: Double {
        guard total > 0 else { return 0 }
        return min(1.0, net / Double(total))
    }

    static let zero = Grade(correct: 0, penalty: 0, total: 0)

    static func + (lhs: Grade, rhs: Grade) -> Grade {
        Grade(correct: lhs.correct + rhs.correct,
              penalty: lhs.penalty + rhs.penalty,
              total: lhs.total + rhs.total)
    }
}

enum Grader {

    static func grade(_ solution: Solution, _ answer: StageAnswer) -> Grade {
        if !solution.paint.isEmpty {
            var correct = 0.0
            for (coord, value) in solution.paint {
                if answer.paint[coord] == value { correct += 1 }
            }
            let extras = Set(answer.paint.keys).subtracting(solution.paint.keys)
            let penalty = penaltyFor(extras, solution)
            return Grade(correct: correct, penalty: penalty, total: solution.paint.count)
        }

        if solution.orderMatters {
            var correct = 0.0
            for (i, coord) in solution.required.enumerated() {
                if i < answer.cells.count && answer.cells[i] == coord { correct += 1 }
            }
            let extras = Set(answer.cells).subtracting(solution.requiredSet)
            let penalty = penaltyFor(extras, solution)
            return Grade(correct: correct, penalty: penalty, total: solution.required.count)
        }

        let selected = Set(answer.cells)
        let required = solution.requiredSet
        let correct = Double(selected.intersection(required).count)
        let extras = selected.subtracting(required)
        return Grade(correct: correct, penalty: penaltyFor(extras, solution), total: required.count)
    }

    private static func penaltyFor(_ extras: Set<Coord>, _ solution: Solution) -> Double {
        let trapped = extras.intersection(solution.traps).count
        let plain = extras.count - trapped
        return Double(plain) * solution.extraWeight + Double(trapped) * solution.trapWeight
    }

    static func gradeAll(_ solutions: [Solution], _ answers: [StageAnswer]) -> Grade {
        var total = Grade.zero
        for (i, solution) in solutions.enumerated() {
            let answer = i < answers.count ? answers[i] : StageAnswer()
            total = total + grade(solution, answer)
        }
        return total
    }
}

/// score = (accuracy x 100) + (difficulty x 50) + (boardSize x 20) + (speed x 10)
/// speed  = max(1, timeLimit - elapsedTime)
enum ScoreEngine {
    static let winThreshold: Double = 0.6

    static func speed(timeLimit: Double, elapsed: Double) -> Double {
        max(1.0, timeLimit - elapsed)
    }

    static func score(accuracy: Double, difficulty: Int, boardDimension: Int,
                      timeLimit: Double, elapsed: Double) -> Int {
        let s = speed(timeLimit: timeLimit, elapsed: elapsed)
        let raw = (accuracy * 100.0) + (Double(difficulty) * 50.0) + (Double(boardDimension) * 20.0) + (s * 10.0)
        return Int(raw.rounded())
    }

    static func isWin(_ accuracy: Double) -> Bool { accuracy >= winThreshold }
}
