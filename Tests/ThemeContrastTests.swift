import AppKit
import SwiftUI

private func luminance(_ color: Color) -> Double {
    let c = NSColor(color).usingColorSpace(.sRGB)!
    func lin(_ v: CGFloat) -> Double {
        let x = Double(v)
        return x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * lin(c.redComponent) + 0.7152 * lin(c.greenComponent) + 0.0722 * lin(c.blueComponent)
}

private func contrast(_ a: Color, _ b: Color) -> Double {
    let (x, y) = (luminance(a), luminance(b))
    return (max(x, y) + 0.05) / (min(x, y) + 0.05)
}

/// Text on cards must reach 4.5:1 in every theme.
func testThemeTextContrast() {
    for app in AppTheme.allCases {
        let t = app.theme
        assertTrue(contrast(t.textPrimary, t.cardBg) >= 4.5, "\(t.name) primary text contrast")
        assertTrue(contrast(t.textSecondary, t.cardBg) >= 4.5, "\(t.name) secondary text contrast")
        assertTrue(contrast(t.accentText, t.cardBg) >= 4.5, "\(t.name) accent text contrast")
        assertTrue(contrast(t.warningText, t.cardBg) >= 4.5, "\(t.name) warning text contrast")
        assertTrue(contrast(t.successText, t.cardBg) >= 4.5, "\(t.name) success text contrast")
    }
}

/// Dark Mode twins: text reads on cards, the accent works as a fill and carries its button label.
func testDarkThemeContrast() {
    for app in AppTheme.allCases {
        let light = app.theme(dark: false)
        let t = app.theme(dark: true)
        assertTrue(!t.isLight, "\(t.name) dark twin is dark")
        assertTrue(light.isLight, "\(t.name) light theme is light")
        assertTrue(t.name == light.name, "\(t.name) dark twin keeps the theme name")
        assertTrue(contrast(t.textPrimary, t.cardBg) >= 4.5, "\(t.name) dark primary text contrast")
        assertTrue(contrast(t.textSecondary, t.cardBg) >= 4.5, "\(t.name) dark secondary text contrast")
        assertTrue(contrast(t.textSecondary, t.bgDark) >= 4.5, "\(t.name) dark secondary text on ground")
        assertTrue(contrast(t.accentText, t.cardBg) >= 4.5, "\(t.name) dark accent text contrast")
        assertTrue(contrast(t.warningText, t.cardBg) >= 4.5, "\(t.name) dark warning text contrast")
        assertTrue(contrast(t.successText, t.cardBg) >= 4.5, "\(t.name) dark success text contrast")
        assertTrue(contrast(t.dangerText, t.cardBg) >= 4.5, "\(t.name) dark danger text contrast")
        assertTrue(contrast(t.accentColor, t.cardBg) >= 3, "\(t.name) dark accent fill visible on card")
        assertTrue(contrast(t.actionButtonForeground, t.accentColor) >= 4.5, "\(t.name) dark Clock In label contrast")
    }
}

/// Red error text reads on the card in light themes too.
func testDangerTextContrast() {
    for app in AppTheme.allCases {
        let t = app.theme
        assertTrue(contrast(t.dangerText, t.cardBg) >= 4.5, "\(t.name) danger text contrast")
    }
}

/// Light/Dark is the user's choice, saved with the theme, and picks the matching palette.
@MainActor
func testThemeAppearanceChoice() {
    let suite = "skeval-theme-test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let manager = ThemeManager(defaults: defaults)
    assertTrue(manager.appearance == .light, "appearance defaults to Light")
    assertTrue(manager.theme == manager.current.theme(dark: false), "Light uses the light palette")

    manager.current = .matcha
    manager.appearance = .dark
    assertTrue(manager.theme == AppTheme.matcha.theme(dark: true), "Dark uses the chosen theme's dark twin")

    let reloaded = ThemeManager(defaults: defaults)
    assertTrue(reloaded.appearance == .dark, "Dark choice persists across launches")
    assertTrue(reloaded.current == .matcha, "theme choice persists alongside appearance")
}

/// Icons, the Clock Out label, and every palette meet their floors in light and dark.
func testThemeGraphicContrast() {
    for app in AppTheme.allCases {
        for t in [app.theme(dark: false), app.theme(dark: true)] {
            let mode = t.isLight ? "light" : "dark"
            assertTrue(contrast(t.accentIcon, t.cardBg) >= 3, "\(t.name) \(mode) accent icon contrast")
            assertTrue(contrast(.white, t.dangerFill) >= 4.5, "\(t.name) \(mode) Clock Out label on light end")
            assertTrue(contrast(.white, t.dangerFillDeep) >= 4.5, "\(t.name) \(mode) Clock Out label on dark end")
        }
    }
}
