import SwiftUI

struct DashboardSettingsView: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme

    @State private var launchAtLogin = LaunchAtLoginHelper.isEnabled
    @State private var themeManager = ThemeManager.shared
    @State private var customCurrency: String = ""
    @State private var isCustomCurrency: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preferences & Settings")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                    Text("Configure your work targets, billing hourly rates, currency, and visual themes.")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                }

                // 1. Productivity Goals Section
                ProductivityGoalsCard(vm: vm, theme: theme)

                // 2. Billing & Monetary Settings Section
                BillingCard(
                    vm: vm,
                    theme: theme,
                    customCurrency: $customCurrency,
                    isCustomCurrency: $isCustomCurrency
                )

                // 3. App Theme & Appearance Section
                ThemeCard(themeManager: themeManager, theme: theme)

                // 4. System & Integration
                SystemCard(
                    launchAtLogin: $launchAtLogin,
                    theme: theme
                )
            }
            .padding(24)
        }
        .background(theme.bgDark)
        .onAppear {
            let standardCurrencies = ["₹", "$", "€", "£"]
            if !standardCurrencies.contains(vm.goal.currencySymbol) {
                isCustomCurrency = true
                customCurrency = vm.goal.currencySymbol
            }
        }
    }
}

// MARK: - Productivity Goals Card

private struct ProductivityGoalsCard: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("PRODUCTIVITY GOALS", systemImage: "target")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(theme.neonTeal)
                .kerning(1.0)

            VStack(spacing: 12) {
                GoalRow(
                    title: "Daily Goal",
                    subtitle: "Target active sprint hours per working day",
                    valueLabel: vm.goal.goalLabel,
                    value: $vm.goal.dailyGoalHours,
                    range: 1...16,
                    step: 0.5,
                    minLabel: "1h",
                    maxLabel: "16h",
                    theme: theme
                )

                Divider().background(theme.dividerColor)

                GoalRow(
                    title: "Weekly Goal",
                    subtitle: "Cumulative 7-day target for dashboard tracking",
                    valueLabel: vm.goal.weeklyGoalLabel,
                    value: $vm.goal.weeklyGoalHours,
                    range: 5...80,
                    step: 1.0,
                    minLabel: "5h",
                    maxLabel: "80h",
                    theme: theme
                )

                Divider().background(theme.dividerColor)

                GoalRow(
                    title: "Monthly Goal",
                    subtitle: "Monthly macro-benchmark for billing and consistency",
                    valueLabel: vm.goal.monthlyGoalLabel,
                    value: $vm.goal.monthlyGoalHours,
                    range: 20...300,
                    step: 5.0,
                    minLabel: "20h",
                    maxLabel: "300h",
                    theme: theme
                )
            }
            .padding(16)
            .background(theme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder, lineWidth: 1))
        }
    }
}

// MARK: - Billing Card

private struct BillingCard: View {
    @Bindable var vm: TimerViewModel
    let theme: PopoverTheme
    @Binding var customCurrency: String
    @Binding var isCustomCurrency: Bool

    private let standardCurrencies = ["₹", "$", "€", "£"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("BILLING & MONETARY EARNINGS", systemImage: "indianrupeesign.circle.fill")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(theme.neonTeal)
                .kerning(1.0)

            VStack(spacing: 16) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Hourly Rate")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.textPrimary)
                        Text("Applied to net sprint hours to compute monetary earnings")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Text(vm.goal.currencySymbol)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.neonTeal)

                        TextField("0.00", value: $vm.goal.hourlyRate, format: .number)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(theme.bgDark)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.cardBorder, lineWidth: 1))

                        Text("/ hr")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                    }
                }

                Divider().background(theme.dividerColor)

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Currency Symbol")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.textPrimary)
                        Text("Displayed alongside earnings across all dashboard widgets")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        ForEach(standardCurrencies, id: \.self) { symbol in
                            let isSelected = vm.goal.currencySymbol == symbol && !isCustomCurrency
                            Button(action: {
                                isCustomCurrency = false
                                vm.goal.currencySymbol = symbol
                            }) {
                                Text(symbol)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
                                    .frame(width: 34, height: 28)
                                    .background(isSelected ? theme.neonTeal.opacity(0.2) : theme.bgDark)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSelected ? theme.neonTeal : theme.cardBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: {
                            isCustomCurrency = true
                            if !customCurrency.isEmpty {
                                vm.goal.currencySymbol = customCurrency
                            }
                        }) {
                            Text("Custom")
                                .font(.system(size: 11, weight: isCustomCurrency ? .bold : .medium, design: .rounded))
                                .foregroundColor(isCustomCurrency ? theme.textPrimary : theme.textSecondary)
                                .padding(.horizontal, 8)
                                .frame(height: 28)
                                .background(isCustomCurrency ? theme.neonTeal.opacity(0.2) : theme.bgDark)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isCustomCurrency ? theme.neonTeal : theme.cardBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                        if isCustomCurrency {
                            TextField("Sym", text: $customCurrency)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .frame(width: 45)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(theme.bgDark)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.neonTeal, lineWidth: 1))
                                .onChange(of: customCurrency) { _, newValue in
                                    if !newValue.isEmpty {
                                        vm.goal.currencySymbol = newValue
                                    }
                                }
                        }
                    }
                }

                HStack {
                    Text("Example Rate Display:")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Text(EarningsCalculator.format(amount: vm.goal.hourlyRate > 0 ? vm.goal.hourlyRate * 8 : 4000, currencySymbol: vm.goal.currencySymbol) + " for 8 hours")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.neonTeal)
                }
                .padding(.top, 2)
            }
            .padding(16)
            .background(theme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder, lineWidth: 1))
        }
    }
}

// MARK: - Theme Card

private struct ThemeCard: View {
    @Bindable var themeManager: ThemeManager
    let theme: PopoverTheme

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("THEME & COLOR PALETTE", systemImage: "paintpalette.fill")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(theme.neonTeal)
                .kerning(1.0)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(AppTheme.allCases) { appTheme in
                    let isSelected = themeManager.current == appTheme
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            themeManager.current = appTheme
                        }
                    }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(appTheme.theme.accentColor)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))

                            Text(appTheme.displayName)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                                .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(appTheme.theme.accentColor)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(isSelected ? appTheme.theme.cardBg : theme.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? appTheme.theme.accentColor : theme.cardBorder, lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(theme.cardBg.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder, lineWidth: 1))
        }
    }
}

// MARK: - System Card

private struct SystemCard: View {
    @Binding var launchAtLogin: Bool
    let theme: PopoverTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("SYSTEM & INTEGRATION", systemImage: "macwindow")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(theme.neonTeal)
                .kerning(1.0)

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Launch at Login")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.textPrimary)
                        Text("Automatically start Skeval Timer in the background when logging into your Mac")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(theme.neonTeal)
                        .onChange(of: launchAtLogin) { _, newValue in
                            LaunchAtLoginHelper.setEnabled(newValue)
                        }
                }

                Divider().background(theme.dividerColor)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Global Clock In / Out Hotkey")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.textPrimary)
                        Text("Toggle active sprint timer from anywhere across macOS")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(theme.textSecondary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(["⌘", "⌥", "⇧", "C"], id: \.self) { key in
                            Text(key)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.textPrimary)
                                .frame(minWidth: 20, minHeight: 20)
                                .padding(.horizontal, 4)
                                .background(theme.bgDark)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.cardBorder, lineWidth: 1))
                        }
                    }
                }
            }
            .padding(16)
            .background(theme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder, lineWidth: 1))
        }
    }
}

private struct GoalRow: View {
    let title: String
    let subtitle: String
    let valueLabel: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let minLabel: String
    let maxLabel: String
    let theme: PopoverTheme

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()

                Text(valueLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.neonTeal)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(theme.neonTeal.opacity(0.12))
                    .clipShape(Capsule())
            }

            Slider(value: $value, in: range, step: step)
                .tint(theme.neonTeal)
                .controlSize(.small)

            HStack {
                Text(minLabel)
                Spacer()
                Text(maxLabel)
            }
            .font(.system(size: 9, weight: .regular, design: .rounded))
            .foregroundColor(theme.textSecondary)
        }
    }
}
