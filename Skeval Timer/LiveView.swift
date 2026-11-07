import SwiftUI

/// Runs `content` in its own view so values that change every timer tick
/// (elapsed time, live totals) re-render only this piece, not the page around it.
struct Live<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View { content() }
}
