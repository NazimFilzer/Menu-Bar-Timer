import AppKit

@MainActor
final class StatusBarPresenter {
    enum PillState: Equatable {
        case running
        case paused
        case idle
    }

    private let statusItem: NSStatusItem
    private struct Presentation: Equatable {
        let text: String
        let state: PillState
        let themeName: String
        let isLight: Bool
        /// Whole percent of the daily goal, so the image is rebuilt at most once per percent.
        let progressPercent: Int?
    }
    private var lastPresentation: Presentation?

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
    }

    /// - Parameter goalProgress: today's share of the daily goal, or nil to draw the plain dot.
    func update(state: SprintState, accumulatedTotal: TimeInterval, pauseElapsed: TimeInterval = 0, theme: PopoverTheme? = nil,
                goalProgress: Double? = nil, force: Bool = false) {
        guard let button = statusItem.button else { return }
        button.title = ""

        let effectiveTheme = theme ?? ThemeManager.shared.theme
        let percent = goalProgress.map { $0.isFinite ? Int((min(1, max(0, $0)) * 100).rounded(.down)) : 0 }
        let presentation = presentation(state: state, accumulatedTotal: accumulatedTotal,
                                        pauseElapsed: pauseElapsed, theme: effectiveTheme, progressPercent: percent)
        let progressText = percent.map { ", \($0) percent of daily goal" } ?? ""
        button.setAccessibilityLabel("Skeval Timer, \(state.statusTitle.lowercased()), \(presentation.text)\(progressText)")
        // Only rebuild the CoreGraphics pill image when something actually changed.
        guard force || presentation != lastPresentation else { return }
        lastPresentation = presentation
        button.image = makePillImage(text: presentation.text, state: presentation.state, theme: effectiveTheme,
                                     progress: presentation.progressPercent.map { Double($0) / 100 })
        button.image?.isTemplate = false
    }

    private func presentation(state: SprintState, accumulatedTotal: TimeInterval,
                              pauseElapsed: TimeInterval, theme: PopoverTheme, progressPercent: Int?) -> Presentation {
        let (name, isLight) = (theme.name, theme.isLight)
        if state.isPaused {
            return Presentation(text: TimeFormatter.format(clock: pauseElapsed), state: .paused, themeName: name, isLight: isLight, progressPercent: progressPercent)
        }
        if state.isRunning {
            return Presentation(text: TimeFormatter.format(clock: state.currentElapsed), state: .running, themeName: name, isLight: isLight, progressPercent: progressPercent)
        }
        return Presentation(text: TimeFormatter.format(clock: accumulatedTotal), state: .idle, themeName: name, isLight: isLight, progressPercent: progressPercent)
    }

    func makePillImage(text: String, state: PillState, theme: PopoverTheme? = nil, progress: Double? = nil) -> NSImage {
        let effectiveTheme = theme ?? ThemeManager.shared.theme
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        let fgColor = effectiveTheme.statusTextNSColor(isIdle: state == .idle)
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: fgColor
        ]
        let textSize = (text as NSString).size(withAttributes: textAttrs)

        // The progress ring takes the dot's place and needs a little more room.
        let dotSize: CGFloat = progress == nil ? 6 : 10
        let gap: CGFloat = 5
        let paddingX: CGFloat = 8
        let pillHeight: CGFloat = 19
        let pillWidth = paddingX + dotSize + gap + ceil(textSize.width) + paddingX

        let size = NSSize(width: pillWidth, height: pillHeight)
        let img = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let pillRect = CGRect(x: 1, y: 1, width: pillWidth - 2, height: pillHeight - 2)
            let cornerRadius = pillRect.height / 2

            let pillColor = Self.pillColor(state: state, theme: effectiveTheme)

            let pillPath = CGPath(roundedRect: pillRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            ctx.setFillColor(pillColor.cgColor)
            ctx.addPath(pillPath)
            ctx.fillPath()

            if let progress {
                Self.drawRing(progress: progress, state: state, context: ctx, foreground: fgColor,
                              padding: paddingX, height: pillHeight, size: dotSize)
            } else {
                Self.drawSymbol(state: state, context: ctx, foreground: fgColor,
                                padding: paddingX, height: pillHeight, dotSize: dotSize)
            }

            let textX = paddingX + dotSize + gap
            let textY = (pillHeight - textSize.height) / 2 + 0.5
            (text as NSString).draw(at: CGPoint(x: textX, y: textY), withAttributes: textAttrs)

            return true
        }
        img.isTemplate = false
        return img
    }
    private static func pillColor(state: PillState, theme: PopoverTheme) -> NSColor {
        switch state {
        case .running: return theme.accentNSColor
        case .paused: return theme.pausedNSColor
        case .idle: return NSColor(white: 0.30, alpha: 0.95)
        }
    }

    /// Daily-goal progress: a faint full track and a clockwise arc from 12 o'clock, in the text colour.
    private static func drawRing(progress: Double, state: PillState, context: CGContext, foreground: NSColor,
                                 padding: CGFloat, height: CGFloat, size: CGFloat) {
        let lineWidth: CGFloat = 2
        let rect = CGRect(x: padding, y: (height - size) / 2, width: size, height: size).insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let color = state == .idle ? NSColor(white: 0.85, alpha: 0.95) : foreground
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setStrokeColor(color.withAlphaComponent(0.3).cgColor)
        context.strokeEllipse(in: rect)
        guard progress > 0 else { return }
        context.setStrokeColor(color.cgColor)
        if progress >= 1 {
            context.strokeEllipse(in: rect)
            return
        }
        let start = CGFloat.pi / 2
        context.addArc(center: center, radius: rect.width / 2, startAngle: start,
                       endAngle: start - CGFloat(progress) * 2 * .pi, clockwise: true)
        context.strokePath()
    }

    private static func drawSymbol(state: PillState, context: CGContext, foreground: NSColor,
                            padding: CGFloat, height: CGFloat, dotSize: CGFloat) {
        if state == .paused {
            context.setFillColor(foreground.cgColor)
            for x in [padding, padding + 4] {
                context.fill(CGRect(x: x, y: (height - 7) / 2, width: 2, height: 7))
            }
            return
        }
        let color = state == .idle ? NSColor(white: 0.75, alpha: 0.8) : foreground
        context.setFillColor(color.cgColor)
        context.addEllipse(in: CGRect(x: padding, y: (height - dotSize) / 2, width: dotSize, height: dotSize))
        context.fillPath()
    }

}
