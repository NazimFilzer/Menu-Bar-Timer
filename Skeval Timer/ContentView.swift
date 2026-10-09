import SwiftUI

// Preview host only — not used at runtime.
#if DEBUG && canImport(PreviewsMacros)
#Preview {
    PopoverView(vm: TimerViewModel())
        .preferredColorScheme(.dark)
}
#endif
