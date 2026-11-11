import SwiftUI

// MARK: - Colour

enum ProfileColor {
    private static let palette: [Color] = [
        Color(red: 0.16, green: 0.69, blue: 0.62), // teal
        Color(red: 0.36, green: 0.47, blue: 0.95), // blue
        Color(red: 0.93, green: 0.55, blue: 0.20), // orange
        Color(red: 0.70, green: 0.40, blue: 0.90), // purple
        Color(red: 0.90, green: 0.33, blue: 0.45), // rose
        Color(red: 0.45, green: 0.70, blue: 0.25), // green
        Color(red: 0.85, green: 0.70, blue: 0.15), // gold
        Color(red: 0.45, green: 0.52, blue: 0.60), // slate
    ]

    static func color(_ index: Int) -> Color {
        palette[((index % palette.count) + palette.count) % palette.count]
    }
}

struct ProfileDot: View {
    let profile: Profile
    var size: CGFloat = 9

    var body: some View {
        Circle().fill(ProfileColor.color(profile.colorIndex))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Popover label (not clickable)

struct PopoverProfileLabel: View {
    let vm: TimerViewModel
    let theme: PopoverTheme

    var body: some View {
        if let profile = vm.activeProfile {
            HStack(spacing: 5) {
                ProfileDot(profile: profile, size: 7)
                Text(profile.name)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Profile \(profile.name)")
        }
    }
}

// MARK: - Dashboard sidebar switcher

struct ProfileSwitcher: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme
    @State private var pendingSwitch: Profile?

    var body: some View {
        if let profiles = vm.profiles {
            let active = profiles.active
            let blocked = vm.profileSwitchAvailability == .blocked
            Menu {
                ForEach(profiles.profiles) { profile in
                    Button {
                        choose(profile)
                    } label: {
                        if profile.id == active.id {
                            Label(profile.name, systemImage: "checkmark")
                        } else {
                            Text(profile.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    ProfileDot(profile: active, size: 10)
                    Text(active.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(theme.bgDark)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.cardBorder, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .disabled(blocked)
            .help(blocked ? "Resolve the sleep decision hold or Recovery Sprint before switching profiles" : "Switch profile")
            .accessibilityLabel("Profile \(active.name)")
            .confirmationDialog(
                pendingSwitch.map { "Clock out of \(active.name) and switch to \($0.name)?" } ?? "",
                isPresented: isPresent($pendingSwitch),
                presenting: pendingSwitch
            ) { target in
                Button("Clock Out & Switch") {
                    vm.switchProfile(to: target.id, clockingOut: true)
                    pendingSwitch = nil
                }
                Button("Cancel", role: .cancel) { pendingSwitch = nil }
            } message: { _ in
                Text("The running sprint is saved to \(active.name).")
            }
        }
    }

    private func choose(_ profile: Profile) {
        switch vm.profileSwitchAvailability {
        case .allowed: vm.switchProfile(to: profile.id)
        case .needsClockOut: pendingSwitch = profile
        case .blocked: break
        }
    }
}

// MARK: - Settings card

struct ProfilesSettingsCard: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme

    @State private var newName = ""
    @State private var startFromDefaults = false
    @State private var addError: String?
    @State private var renamingID: UUID?
    @State private var renameText = ""
    @State private var renameError: String?
    /// The profile awaiting delete confirmation, with its history summary loaded once on tap.
    @State private var pendingDelete: PendingProfileDelete?
    @State private var deleteError: String?

    var body: some View {
        if let profiles = vm.profiles {
            VStack(alignment: .leading, spacing: 14) {
                Label("PROFILES", systemImage: "person.2")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(theme.accentText)
                    .kerning(1.0)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Each profile keeps its own history, goals, rate, and schedule. Switch from the top of the sidebar.")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(theme.textSecondary)

                    ForEach(profiles.profiles) { profile in
                        row(profile, isActive: profile.id == profiles.active.id)
                        Divider().background(theme.dividerColor)
                    }

                    addRow
                    if let deleteError { Text(deleteError).font(.caption).foregroundStyle(theme.dangerText) }
                }
                .padding(16)
                .background(theme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder, lineWidth: 1))
            }
            .confirmationDialog(
                pendingDelete.map { "Delete \($0.profile.name)?" } ?? "",
                isPresented: isPresent($pendingDelete),
                presenting: pendingDelete
            ) { pending in
                Button("Delete Profile", role: .destructive) { delete(pending.profile) }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: { pending in
                Text(pending.message)
            }
        }
    }

    @ViewBuilder
    private func row(_ profile: Profile, isActive: Bool) -> some View {
        let deleteBlocker = vm.profileDeleteBlocker(for: profile.id)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                ProfileDot(profile: profile, size: 11)
                if renamingID == profile.id {
                    TextField("Profile name", text: $renameText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                        .onSubmit { commitRename(profile) }
                        .accessibilityLabel("New name for \(profile.name)")
                    Button("Save") { commitRename(profile) }
                    Button("Cancel") { renamingID = nil; renameError = nil }
                } else {
                    Text(profile.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                    if isActive {
                        Text("Active")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.accentText)
                    }
                    Spacer()
                    Button("Rename") {
                        renamingID = profile.id
                        renameText = profile.name
                        renameError = nil
                    }
                    Button("Delete", role: .destructive) {
                        deleteError = nil
                        if let summary = vm.profiles?.historySummary(for: profile.id) {
                            pendingDelete = PendingProfileDelete(profile: profile, summary: summary)
                        }
                    }
                    .disabled(deleteBlocker != nil)
                    .help(deleteBlocker?.localizedDescription ?? "Delete \(profile.name)")
                }
            }
            if renamingID == profile.id, let renameError {
                Text(renameError).font(.caption).foregroundStyle(theme.dangerText)
            }
        }
        .controlSize(.small)
    }

    private var addRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("New profile name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                    .onSubmit(add)
                    .accessibilityLabel("New profile name")
                Toggle("Start from defaults", isOn: $startFromDefaults)
                    .toggleStyle(.checkbox)
                    .help("Off copies goals, rate, currency, and schedule from the active profile")
                Spacer()
                Button("Add Profile", systemImage: "plus", action: add)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .controlSize(.small)
            if let addError { Text(addError).font(.caption).foregroundStyle(theme.dangerText) }
        }
    }

    private func add() {
        do {
            try vm.addProfile(name: newName, startFromDefaults: startFromDefaults)
            newName = ""
            addError = nil
        } catch {
            addError = error.localizedDescription
        }
    }

    private func commitRename(_ profile: Profile) {
        do {
            try vm.renameProfile(id: profile.id, to: renameText)
            renamingID = nil
            renameError = nil
        } catch {
            renameError = error.localizedDescription
        }
    }

    private func delete(_ profile: Profile) {
        do {
            try vm.deleteProfile(id: profile.id)
            deleteError = nil
        } catch {
            deleteError = error.localizedDescription
        }
        pendingDelete = nil
    }

}

private struct PendingProfileDelete {
    let profile: Profile
    let summary: ProfileHistorySummary

    var message: String {
        let hours = TimeFormatter.format(shortDuration: summary.workedSeconds)
        let days = "\(summary.days) day\(summary.days == 1 ? "" : "s")"
        return "This removes \(hours) of work across \(days), plus this profile's settings. A backup is kept in the app's Backups folder."
    }
}

/// A presentation binding that is true while `item` holds a value and clears it on dismiss.
private func isPresent<Item>(_ item: Binding<Item?>) -> Binding<Bool> {
    Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
}
