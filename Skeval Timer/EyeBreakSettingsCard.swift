import SwiftUI
import UserNotifications

struct EyeBreakSettingsCard: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationStatus = "Allow Skeval Timer notifications in System Settings. Focus modes may silence reminders."

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("EYE-BREAK REMINDERS", systemImage: "eye")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(theme.neonTeal)
                .kerning(1)
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Remind me to look away", isOn: Binding(
                    get: { vm.eyeBreakSettings.isEnabled },
                    set: { vm.updateEyeBreakEnabled($0) }
                ))
                .toggleStyle(.switch)
                .tint(theme.neonTeal)
                Picker("Remind every", selection: Binding(
                    get: { vm.eyeBreakSettings.intervalMinutes },
                    set: { vm.updateEyeBreakInterval($0) }
                )) {
                    ForEach(EyeBreakSettings.intervals, id: \.self) { minutes in
                        Text(minutes == 20 ? "20 minutes (20-20-20 guidance)" : "\(minutes) minutes")
                            .tag(minutes)
                    }
                }
                .disabled(!vm.eyeBreakSettings.isEnabled)
                Text("Look at something at least 20 feet (6 metres) away for 20 seconds. Reminders run only during active sprints. Pausing, sleeping, starting a sprint, or changing settings starts a fresh interval; your work timer is not paused by a reminder.")
                Text("The 20-20-20 rule is common eye-strain guidance, not proven prevention of eye damage. The ideal interval is uncertain; 30 and 45 minutes are personal preferences.")
                Link("Read the American Academy of Ophthalmology guidance", destination: URL(string: "https://www.aao.org/eye-health/diseases/what-is-eye-strain")!)
                Text(notificationStatus)
                Link("Open notification settings", destination: URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
            }
            .font(.system(size: 12, design: .rounded))
            .foregroundStyle(theme.textSecondary)
            .padding(16)
            .background(theme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder, lineWidth: 1))
        }
        .task(id: scenePhase) {
            guard scenePhase == .active, Bundle.main.bundleIdentifier != nil else { return }
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationStatus = settings.authorizationStatus == .denied
                ? "Notifications are blocked. Enable Skeval Timer in System Settings → Notifications to receive eye-break reminders."
                : "Allow Skeval Timer notifications in System Settings. Focus modes may silence reminders."
        }
    }
}
