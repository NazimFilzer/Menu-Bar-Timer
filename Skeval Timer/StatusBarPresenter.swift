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
    }
    private var lastPresentation: Presentation?

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
    }

    func update(state: SprintState, accumulatedTotal: TimeInterval, pauseElapsed: TimeInterval = 0, theme: PopoverTheme? = nil, force: Bool = false) {
        guard let button = statusItem.button else { return }
        button.title = ""

        let effectiveTheme = theme ?? ThemeManager.shared.theme
        let presentation = presentation(state: state, accumulatedTotal: accumulatedTotal,
                                        pauseElapsed: pauseElapsed, themeName: effectiveTheme.name)
        button.setAccessibilityLabel("Skeval Timer, \(state.statusTitle.lowercased()), \(presentation.text)")
        guard force || presentation != lastPresentation else { return }
        lastPresentation = presentation
        button.image = makePillImage(text: presentation.text, state: presentation.state, theme: effectiveTheme)
        button.image?.isTemplate = false
    }

    private func presentation(state: SprintState, accumulatedTotal: TimeInterval,
                              pauseElapsed: TimeInterval, themeName: String) -> Presentation {
        if state.isPaused {
            return Presentation(text: TimeFormatter.format(clock: pauseElapsed), state: .paused, themeName: themeName)
        }
        if state.isRunning {
            return Presentation(text: TimeFormatter.format(clock: state.currentElapsed), state: .running, themeName: themeName)
        }
        return Presentation(text: TimeFormatter.format(clock: accumulatedTotal), state: .idle, themeName: themeName)
    }

    func makePillImage(text: String, state: PillState, theme: PopoverTheme? = nil) -> NSImage {
        let effectiveTheme = theme ?? ThemeManager.shared.theme
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        let fgColor = effectiveTheme.statusTextNSColor(isIdle: state == .idle)
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: fgColor
        ]
        let textSize = (text as NSString).size(withAttributes: textAttrs)

        let dotSize: CGFloat = 6
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

            Self.drawSymbol(state: state, context: ctx, foreground: fgColor,
                            padding: paddingX, height: pillHeight, dotSize: dotSize)

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
