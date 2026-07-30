import SwiftUI

struct GameView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var vm: GameViewModel

    let onExit: () -> Void
    let onReplay: () -> Void

    @State private var started = false
    @State private var showQuitConfirm = false

    init(config: SessionConfig, onExit: @escaping () -> Void, onReplay: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: GameViewModel(config: config))
        self.onExit = onExit
        self.onReplay = onReplay
    }

    private var palette: Palette { store.palette }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            if vm.state == .finished {
                ResultView(vm: vm, palette: palette, onExit: onExit, onReplay: onReplay)
            } else {
                playfield
            }

            if vm.state == .paused {
                pauseOverlay
            }
        }
        .onAppear {
            Feedback.shared.soundEnabled = store.settings.soundOn
            Feedback.shared.hapticsEnabled = store.settings.hapticsOn
            if !started {
                started = true
                vm.onFinish = { result in store.record(result: result) }
                vm.start()
            }
        }
    }

    // MARK: - Playfield

    private var playfield: some View {
        VStack(spacing: Metric.spaceS) {
            header
            promptBlock
            timerBlock

            GeometryReader { geo in
                let side = max(80, min(geo.size.width, geo.size.height))
                BoardView(board: vm.visibleBoard,
                          side: side,
                          palette: palette,
                          reveal: vm.state == .preview || vm.stage.recallBoard != nil,
                          selection: vm.selection,
                          showOrder: isOrdered,
                          paintChoices: vm.paintChoices,
                          paintAttribute: paintAttribute,
                          showCoordinates: store.settings.showCoordinates,
                          enabledCell: { vm.canTap($0) },
                          onTap: vm.state == .playing ? { vm.tap($0) } : nil)
                    .frame(width: side, height: side)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                    .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)

            if let attribute = paintAttribute, case .paint(_, let options, _, _) = vm.interaction {
                paletteRow(attribute: attribute, options: options)
            }

            footer
        }
        .padding(.horizontal, Metric.spaceM)
        .padding(.top, Metric.spaceS)
        .padding(.bottom, Metric.spaceS)
    }

    private var isOrdered: Bool {
        switch vm.interaction {
        case .tapOrdered, .tapPath: return true
        default: return false
        }
    }

    private var paintAttribute: PaintAttribute? {
        if case .paint(let attribute, _, _, _) = vm.interaction { return attribute }
        return nil
    }

    private var header: some View {
        HStack(spacing: Metric.spaceS) {
            GlyphButton(glyph: .close, size: 36, iconSize: 16, color: palette.text,
                        background: palette.surface) {
                vm.pause()
                showQuitConfirm = true
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(vm.puzzle.mode.title)
                    .font(AppFont.bodyBold)
                    .foregroundColor(palette.text)
                Text("\(vm.puzzle.size.label) · \(DifficultyProfile(level: vm.puzzle.difficulty).name)\(vm.stageCount > 1 ? " · " + vm.stageLabel : "")")
                    .font(AppFont.caption)
                    .foregroundColor(palette.textSoft)
            }
            Spacer(minLength: 0)
            GlyphButton(glyph: .pause, size: 36, iconSize: 16, color: palette.text,
                        background: palette.surface) {
                vm.pause()
            }
        }
    }

    private var promptBlock: some View {
        HStack(alignment: .top, spacing: Metric.spaceS) {
            GlyphIcon(glyph: vm.state == .preview ? .clock : .target,
                      size: 16,
                      color: vm.state == .preview ? palette.warning : palette.primary,
                      weight: 1.9)
            Text(vm.state == .preview ? vm.stage.previewPrompt : vm.stage.recallPrompt)
                .font(AppFont.caption)
                .foregroundColor(palette.text)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metric.spaceS + 2)
        .padding(.vertical, Metric.spaceS)
        .background(RoundedRectangle(cornerRadius: Metric.cornerS)
            .fill((vm.state == .preview ? palette.warning : palette.primary).opacity(0.12)))
    }

    private var timerBlock: some View {
        HStack(spacing: Metric.spaceS) {
            Text(vm.state == .preview ? "MEMORIZE" : "RECALL")
                .font(AppFont.captionBold)
                .tracking(1.2)
                .foregroundColor(vm.state == .preview ? palette.warning : palette.primary)
            ZStack(alignment: .leading) {
                Capsule().fill(palette.surface).frame(height: 8)
                GeometryReader { geo in
                    Capsule()
                        .fill(vm.state == .preview ? palette.warning : palette.primary)
                        .frame(width: max(0, geo.size.width * barFraction), height: 8)
                }
                .frame(height: 8)
            }
            Text(vm.state == .preview
                 ? String(format: "%.1fs", vm.previewRemaining)
                 : String(format: "%.0fs", vm.recallRemaining))
                .font(AppFont.captionBold)
                .foregroundColor(palette.textSoft)
                .frame(width: 42, alignment: .trailing)
        }
    }

    private var barFraction: Double {
        vm.state == .preview ? (1 - vm.previewProgress) : vm.recallProgress
    }

    private func paletteRow(attribute: PaintAttribute, options: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(attribute.title.uppercased()) BRUSH")
                .font(AppFont.captionBold)
                .tracking(1.0)
                .foregroundColor(palette.textSoft)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metric.spaceS) {
                    ForEach(options, id: \.self) { value in
                        let object = BoardView.paintObject(attribute: attribute, value: value)
                        let selected = vm.activeOption == value
                        Button {
                            vm.activeOption = value
                            Feedback.shared.tap()
                        } label: {
                            VStack(spacing: 2) {
                                SymbolSwatch(symbol: object.symbol,
                                             direction: object.direction,
                                             level: object.level,
                                             objectSize: object.size,
                                             color: palette.color(for: object.color),
                                             side: 26)
                                Text(BoardView.optionTitle(attribute: attribute, value: value))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(selected ? .white : palette.textSoft)
                            }
                            .frame(width: 58, height: 50)
                            .background(RoundedRectangle(cornerRadius: Metric.cornerS)
                                .fill(selected ? palette.primary : palette.surface))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 52)
        }
    }

    private var footer: some View {
        VStack(spacing: Metric.spaceS) {
            HStack {
                Text(vm.state == .preview ? "Preview" : vm.selectionCountText)
                    .font(AppFont.captionBold)
                    .foregroundColor(palette.textSoft)
                Spacer()
                if vm.state == .playing {
                    Button {
                        vm.clearSelection()
                        Feedback.shared.tap()
                    } label: {
                        Text("Clear")
                            .font(AppFont.captionBold)
                            .foregroundColor(palette.error)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(palette.error.opacity(0.12)))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            if vm.state == .preview {
                PrimaryButton(title: "I am ready", glyph: .check, palette: palette, tint: palette.warning) {
                    vm.skipPreview()
                }
            } else {
                PrimaryButton(title: vm.isLastStage ? "Submit answer" : "Submit stage",
                              glyph: .forward,
                              palette: palette,
                              enabled: vm.canSubmit) {
                    vm.submitStage()
                }
            }
        }
    }

    // MARK: - Pause

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: Metric.spaceM) {
                GlyphIcon(glyph: showQuitConfirm ? .close : .pause, size: 34,
                          color: palette.primary, weight: 2.2)
                Text(showQuitConfirm ? "Leave this session?" : "Paused")
                    .font(AppFont.title)
                    .foregroundColor(palette.text)
                Text(showQuitConfirm
                     ? "Progress in this round will not be saved."
                     : "The timer is stopped. Nothing on the board changes.")
                    .font(AppFont.caption)
                    .foregroundColor(palette.textSoft)
                    .multilineTextAlignment(.center)

                if showQuitConfirm {
                    PrimaryButton(title: "Leave session", glyph: .close, palette: palette,
                                  tint: palette.error) { onExit() }
                    SecondaryButton(title: "Keep playing", glyph: .play, palette: palette) {
                        showQuitConfirm = false
                        vm.resume()
                    }
                } else {
                    PrimaryButton(title: "Resume", glyph: .play, palette: palette) { vm.resume() }
                    SecondaryButton(title: "Restart round", glyph: .refresh, palette: palette) {
                        onReplay()
                    }
                    SecondaryButton(title: "Leave session", glyph: .close, palette: palette,
                                    tint: palette.error) {
                        showQuitConfirm = true
                    }
                }
            }
            .padding(Metric.spaceL)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: Metric.cornerL).fill(palette.background))
            .padding(Metric.spaceL)
        }
    }
}
