import Foundation
import Combine

struct SessionConfig: Equatable {
    var mode: GameModeType
    var difficulty: Int
    var size: BoardSize
    var layoutID: Int
    var isDaily: Bool = false
    var fixedSeed: UInt64? = nil

    var layout: BoardLayout { LayoutCatalog.layout(id: layoutID) }
}

@MainActor
final class GameViewModel: ObservableObject {

    @Published private(set) var puzzle: Puzzle
    @Published var state: GameState = .preview
    @Published var stageIndex = 0
    @Published var frameIndex = 0
    @Published var previewRemaining: Double = 0
    @Published var recallRemaining: Double = 0
    @Published var selection: [Coord] = []
    @Published var paintChoices: [Coord: Int] = [:]
    @Published var activeOption: Int = 0
    @Published var grade: Grade?
    @Published var stageGrades: [Grade] = []
    @Published var result: GameResult?
    @Published var revealSolution = false

    let config: SessionConfig
    var onFinish: ((GameResult) -> Void)?

    private(set) var submittedAnswers: [StageAnswer] = []
    private var timer: Timer?
    private var startedAt = Date()
    private var recorded = false
    private let tick = 0.05

    init(config: SessionConfig) {
        self.config = config
        let seed = config.fixedSeed ?? UInt64.random(in: 1...UInt64.max)
        self.puzzle = PuzzleEngine.generate(mode: config.mode,
                                           difficulty: config.difficulty,
                                           size: config.size,
                                           layout: config.layout,
                                           seed: seed)
        self.recallRemaining = puzzle.timeLimit
    }

    deinit { timer?.invalidate() }

    // MARK: - Derived

    var stage: PuzzleStage { puzzle.stages[min(stageIndex, puzzle.stages.count - 1)] }
    var stageCount: Int { puzzle.stages.count }
    var isLastStage: Bool { stageIndex >= puzzle.stages.count - 1 }
    var interaction: Interaction { stage.interaction }

    var visibleBoard: GameBoard {
        switch state {
        case .preview:
            let frames = stage.frames
            return frames[min(frameIndex, frames.count - 1)]
        case .playing, .paused, .finished:
            if revealSolution { return stage.frames[stage.frames.count - 1] }
            return stage.recallBoard ?? GameBoard(size: puzzle.size)
        }
    }

    var previewProgress: Double {
        guard stage.previewSeconds > 0 else { return 1 }
        return max(0, min(1, 1 - previewRemaining / stage.previewSeconds))
    }

    var recallProgress: Double {
        guard puzzle.timeLimit > 0 else { return 1 }
        return max(0, min(1, recallRemaining / puzzle.timeLimit))
    }

    var selectionCountText: String {
        switch interaction {
        case .paint(_, _, let expected, _):
            return "\(paintChoices.count) / \(expected)"
        case .tapCells(let expected, _, let show):
            return show ? "\(selection.count) / \(expected)" : "\(selection.count) selected"
        case .tapOrdered(let expected), .tapPath(let expected):
            return "\(selection.count) / \(expected)"
        }
    }

    var canSubmit: Bool {
        interaction.isPaint ? !paintChoices.isEmpty : !selection.isEmpty
    }

    var stageLabel: String {
        stageCount > 1 ? "Stage \(stageIndex + 1) of \(stageCount)" : "Single stage"
    }

    // MARK: - Lifecycle

    func start() {
        startedAt = Date()
        submittedAnswers = []
        stageGrades = []
        stageIndex = 0
        beginStage()
    }

    private func beginStage() {
        selection = []
        paintChoices = [:]
        frameIndex = 0
        revealSolution = false
        if case .paint(_, let options, _, _) = stage.interaction {
            activeOption = options.first ?? 0
        }
        if stage.sharedPreview && stageIndex > 0 {
            state = .playing
        } else {
            previewRemaining = stage.previewSeconds
            state = .preview
        }
        runTimer()
    }

    private func runTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: tick, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.step() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func step() {
        switch state {
        case .preview:
            previewRemaining = max(0, previewRemaining - tick)
            let elapsed = stage.previewSeconds - previewRemaining
            let interval = max(0.05, stage.frameInterval)
            frameIndex = min(stage.frames.count - 1, Int(elapsed / interval))
            if previewRemaining <= 0 {
                frameIndex = stage.frames.count - 1
                state = .playing
                Feedback.shared.confirm()
            }
        case .playing:
            recallRemaining = max(0, recallRemaining - tick)
            if recallRemaining <= 0 { timeUp() }
        case .paused, .finished:
            break
        }
    }

    func skipPreview() {
        guard state == .preview else { return }
        previewRemaining = 0
        frameIndex = stage.frames.count - 1
        state = .playing
        Feedback.shared.confirm()
    }

    func pause() {
        guard state == .preview || state == .playing else { return }
        timer?.invalidate(); timer = nil
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        state = previewRemaining > 0 && !(stage.sharedPreview && stageIndex > 0) ? .preview : .playing
        runTimer()
    }

    // MARK: - Interaction

    func canTap(_ coord: Coord) -> Bool {
        guard state == .playing else { return false }
        switch interaction {
        case .tapPath:
            if selection.isEmpty { return true }
            if selection.contains(coord) { return coord == selection[selection.count - 1] }
            guard let last = selection.last else { return true }
            let dr = abs(last.row - coord.row), dc = abs(last.column - coord.column)
            return dr + dc == 1 && selection.count < interaction.expected
        case .tapOrdered(let expected):
            return selection.contains(coord) || selection.count < expected
        case .tapCells(_, let maxSelections, _):
            return selection.contains(coord) || selection.count < maxSelections
        case .paint(_, _, _, let maxSelections):
            return paintChoices[coord] != nil || paintChoices.count < maxSelections
        }
    }

    func tap(_ coord: Coord) {
        guard state == .playing, canTap(coord) else { return }
        Feedback.shared.tap()
        switch interaction {
        case .paint:
            if paintChoices[coord] == activeOption {
                paintChoices.removeValue(forKey: coord)
            } else {
                paintChoices[coord] = activeOption
            }
        case .tapPath:
            if let last = selection.last, last == coord {
                selection.removeLast()
            } else if !selection.contains(coord) {
                selection.append(coord)
            }
        case .tapOrdered, .tapCells:
            if let i = selection.firstIndex(of: coord) {
                selection.remove(at: i)
            } else {
                selection.append(coord)
            }
        }
    }

    func clearSelection() {
        selection = []
        paintChoices = [:]
    }

    private func currentAnswer() -> StageAnswer {
        interaction.isPaint ? StageAnswer(cells: [], paint: paintChoices)
                            : StageAnswer(cells: selection, paint: [:])
    }

    func submitStage() {
        guard state == .playing else { return }
        let answer = currentAnswer()
        submittedAnswers.append(answer)
        stageGrades.append(Grader.grade(stage.solution, answer))
        if isLastStage {
            finish()
        } else {
            stageIndex += 1
            beginStage()
        }
    }

    private func timeUp() {
        submittedAnswers.append(currentAnswer())
        stageGrades.append(Grader.grade(stage.solution, currentAnswer()))
        while submittedAnswers.count < puzzle.stages.count {
            let index = submittedAnswers.count
            submittedAnswers.append(StageAnswer())
            stageGrades.append(Grader.grade(puzzle.stages[index].solution, StageAnswer()))
        }
        finish()
    }

    private func finish() {
        timer?.invalidate(); timer = nil
        let total = Grader.gradeAll(puzzle.stages.map { $0.solution }, submittedAnswers)
        grade = total
        let elapsed = max(0, puzzle.timeLimit - recallRemaining)
        let score = ScoreEngine.score(accuracy: total.accuracy,
                                      difficulty: puzzle.difficulty,
                                      boardDimension: puzzle.size.dimension,
                                      timeLimit: puzzle.timeLimit,
                                      elapsed: elapsed)
        let won = ScoreEngine.isWin(total.accuracy)
        let outcome = GameResult(score: score,
                                 accuracy: total.accuracy,
                                 duration: Date().timeIntervalSince(startedAt),
                                 modeRaw: puzzle.mode.rawValue,
                                 difficulty: puzzle.difficulty,
                                 boardDimension: puzzle.size.dimension,
                                 date: Date(),
                                 won: won,
                                 wasDaily: config.isDaily)
        result = outcome
        state = .finished
        if !recorded {
            recorded = true
            onFinish?(outcome)
        }
        won ? Feedback.shared.success() : Feedback.shared.failure()
    }

    // MARK: - Result helpers

    var speedBonus: Double {
        ScoreEngine.speed(timeLimit: puzzle.timeLimit,
                          elapsed: max(0, puzzle.timeLimit - recallRemaining))
    }

    var elapsedRecall: Double { max(0, puzzle.timeLimit - recallRemaining) }

    func solutionCells(forStage index: Int) -> Set<Coord> {
        guard index < puzzle.stages.count else { return [] }
        return puzzle.stages[index].solution.requiredSet
    }
}
