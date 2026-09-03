import AppKit

@MainActor
final class StatusBarPresenter {
    enum PillState: Equatable {
        case running
        case paused
        case idle
    }

    private let statusItem: NSStatusItem
    private var lastSecond: Int = -1
    private var lastPillState: PillState = .idle

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
    }

    func update(state: SprintState, accumulatedTotal: TimeInterval, force: Bool = false) {
        guard let button = statusItem.button else { return }
        button.title = ""

        if state.isRunning {
            let elapsed = Int(state.currentElapsed)
            let pillState: PillState = state.isPaused ? .paused : .running

            if !force && elapsed == lastSecond && pillState == lastPillState {
                return
            }

            lastSecond = elapsed
            lastPillState = pillState

            let text = TimeFormatter.format(clock: state.currentElapsed)
            button.image = makePillImage(text: text, state: pillState)
            button.image?.isTemplate = false
        } else {
            let text = accumulatedTotal > 0
                ? TimeFormatter.format(clock: accumulatedTotal)
                : "00:00:00"
            let pillState: PillState = .idle

            if !force && pillState == lastPillState && lastSecond == -1 {
                return
            }

            lastSecond = -1
            lastPillState = pillState

            button.image = makePillImage(text: text, state: pillState)
            button.image?.isTemplate = false
        }
    }

    func makePillImage(text: String, state: PillState) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        let textColor: NSColor = (state == .paused) ? .black : .white
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
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

            let pillColor: NSColor
            switch state {
            case .running:
                pillColor = NSColor(red: 0.95, green: 0.22, blue: 0.24, alpha: 0.95)
            case .paused:
                pillColor = NSColor(red: 1.0, green: 0.68, blue: 0.0, alpha: 0.95)
            case .idle:
                pillColor = NSColor(white: 0.30, alpha: 0.95)
            }

            let pillPath = CGPath(roundedRect: pillRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            ctx.setFillColor(pillColor.cgColor)
            ctx.addPath(pillPath)
            ctx.fillPath()

            switch state {
            case .paused:
                let barW: CGFloat = 2
                let barH: CGFloat = 7
                let barY = (pillHeight - barH) / 2
                let bar1X = paddingX
                let bar2X = paddingX + barW + 2
                ctx.setFillColor(NSColor.black.cgColor)
                ctx.fill(CGRect(x: bar1X, y: barY, width: barW, height: barH))
                ctx.fill(CGRect(x: bar2X, y: barY, width: barW, height: barH))
            case .running:
                let dotY = (pillHeight - dotSize) / 2
                let dotRect = CGRect(x: paddingX, y: dotY, width: dotSize, height: dotSize)
                ctx.setFillColor(NSColor.white.cgColor)
                ctx.addEllipse(in: dotRect)
                ctx.fillPath()
            case .idle:
                let dotY = (pillHeight - dotSize) / 2
                let dotRect = CGRect(x: paddingX, y: dotY, width: dotSize, height: dotSize)
                ctx.setFillColor(NSColor(white: 0.75, alpha: 0.8).cgColor)
                ctx.addEllipse(in: dotRect)
                ctx.fillPath()
            }

            let textX = paddingX + dotSize + gap
            let textY = (pillHeight - textSize.height) / 2 + 0.5
            (text as NSString).draw(at: CGPoint(x: textX, y: textY), withAttributes: textAttrs)

            return true
        }
        img.isTemplate = false
        return img
    }
}
