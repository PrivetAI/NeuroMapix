import SwiftUI

struct ResultView: View {
    @ObservedObject var vm: GameViewModel
    let palette: Palette
    let onExit: () -> Void
    let onReplay: () -> Void

    @State private var reviewStage = 0

    private var result: GameResult? { vm.result }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Metric.spaceM) {
                headline
                scoreCard
                breakdown
                review
                actions
            }
            .padding(Metric.spaceM)
        }
        .background(palette.background.ignoresSafeArea())
    }

    private var headline: some View {
        HStack(spacing: Metric.spaceM) {
            ZStack {
                Circle().fill((result?.won == true ? palette.accent : palette.warning).opacity(0.15))
                GlyphIcon(glyph: result?.won == true ? .trophy : .refresh,
                          size: 26,
                          color: result?.won == true ? palette.accent : palette.warning,
                          weight: 2.1)
            }
            .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text(result?.won == true ? "Round cleared" : "Round missed")
                    .font(AppFont.title)
                    .foregroundColor(palette.text)
                Text("\(vm.puzzle.mode.title) · \(vm.puzzle.size.label) · \(DifficultyProfile(level: vm.puzzle.difficulty).name)")
                    .font(AppFont.caption)
                    .foregroundColor(palette.textSoft)
            }
            Spacer(minLength: 0)
        }
    }

    private var scoreCard: some View {
        Card(palette: palette) {
            HStack(spacing: Metric.spaceL) {
                ProgressRing(progress: result?.accuracy ?? 0,
                             lineWidth: 9,
                             color: (result?.won == true) ? palette.accent : palette.warning,
                             track: palette.primary.opacity(0.12),
                             side: 96,
                             centerText: "\(Int(round((result?.accuracy ?? 0) * 100)))%",
                             caption: "ACCURACY",
                             textColor: palette.text)
                VStack(alignment: .leading, spacing: Metric.spaceS) {
                    Text("SCORE")
                        .font(AppFont.captionBold)
                        .tracking(1.1)
                        .foregroundColor(palette.textSoft)
                    Text("\(result?.score ?? 0)")
                        .font(AppFont.numeric)
                        .foregroundColor(palette.primary)
                    Text(String(format: "%d of %d elements · %.1fs",
                                Int((vm.grade?.net ?? 0).rounded()),
                                vm.grade?.total ?? 0,
                                vm.elapsedRecall))
                        .font(AppFont.caption)
                        .foregroundColor(palette.textSoft)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var breakdown: some View {
        Card(palette: palette) {
            VStack(alignment: .leading, spacing: Metric.spaceS) {
                SectionHeader(title: "How the score was built", palette: palette)
                row("Accuracy x 100", value: String(format: "%.0f", (result?.accuracy ?? 0) * 100))
                row("Difficulty x 50", value: "\(vm.puzzle.difficulty * 50)")
                row("Board size x 20", value: "\(vm.puzzle.size.dimension * 20)")
                row("Speed x 10", value: String(format: "%.0f", vm.speedBonus * 10))
                Divider().background(palette.gridLine)
                row("Total", value: "\(result?.score ?? 0)", bold: true)
                if let grade = vm.grade, grade.penalty > 0 {
                    Text("Penalty applied: \(String(format: "%.0f", grade.penalty)) element\(grade.penalty == 1 ? "" : "s") for wrong cells.")
                        .font(AppFont.caption)
                        .foregroundColor(palette.error)
                }
                Text(result?.won == true
                     ? "Win streak continues."
                     : "Accuracy below 60% resets the win streak.")
                    .font(AppFont.caption)
                    .foregroundColor(palette.textSoft)
            }
        }
    }

    private func row(_ title: String, value: String, bold: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(bold ? AppFont.bodyBold : AppFont.body)
                .foregroundColor(palette.text)
            Spacer()
            Text(value)
                .font(bold ? AppFont.bodyBold : AppFont.body)
                .foregroundColor(bold ? palette.primary : palette.textSoft)
        }
    }

    private var review: some View {
        Card(palette: palette) {
            VStack(alignment: .leading, spacing: Metric.spaceS) {
                SectionHeader(title: "Review", trailing: vm.stageCount > 1 ? "\(vm.stageCount) stages" : nil,
                              palette: palette)
                if vm.stageCount > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Metric.spaceS) {
                            ForEach(0..<vm.stageCount, id: \.self) { i in
                                Chip(title: "Stage \(i + 1)", selected: reviewStage == i, palette: palette) {
                                    reviewStage = i
                                }
                            }
                        }
                    }
                }
                let index = min(reviewStage, vm.stageCount - 1)
                let stage = vm.puzzle.stages[index]
                let answer = index < vm.submittedAnswers.count ? vm.submittedAnswers[index] : StageAnswer()
                let required = stage.solution.requiredSet
                let chosen: Set<Coord> = stage.solution.paint.isEmpty
                    ? Set(answer.cells) : Set(answer.paint.keys)
                let correct: Set<Coord> = stage.solution.paint.isEmpty
                    ? chosen.intersection(required)
                    : Set(stage.solution.paint.compactMap { key, value in
                        answer.paint[key] == value ? key : nil })
                let wrong = chosen.subtracting(correct)
                let missed = required.subtracting(chosen)

                GeometryReader { geo in
                    let side = min(geo.size.width, 300)
                    BoardView(board: stage.frames[stage.frames.count - 1],
                              side: side,
                              palette: palette,
                              reveal: true,
                              correctCells: correct,
                              missedCells: missed,
                              wrongCells: wrong)
                        .frame(width: geo.size.width, alignment: .center)
                }
                .frame(height: min(300, UIScreen.main.bounds.width - 64))

                HStack(spacing: Metric.spaceM) {
                    legend(color: palette.accent, label: "Correct \(correct.count)")
                    legend(color: palette.error, label: "Wrong \(wrong.count)")
                    legend(color: palette.warning, label: "Missed \(missed.count)")
                }
                if index < vm.stageGrades.count {
                    let g = vm.stageGrades[index]
                    Text(String(format: "Stage accuracy %.0f%% (%.0f of %d)", g.accuracy * 100, g.net, g.total))
                        .font(AppFont.caption)
                        .foregroundColor(palette.textSoft)
                }
                Text("The board above shows the true layout of stage \(index + 1).")
                    .font(AppFont.caption)
                    .foregroundColor(palette.textFaint)
            }
        }
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).stroke(color, lineWidth: 2)
                .frame(width: 13, height: 13)
            Text(label).font(AppFont.caption).foregroundColor(palette.textSoft)
        }
    }

    private var actions: some View {
        VStack(spacing: Metric.spaceS) {
            PrimaryButton(title: "Play again", glyph: .refresh, palette: palette) { onReplay() }
            SecondaryButton(title: "Back to home", glyph: .home, palette: palette) { onExit() }
        }
    }
}
