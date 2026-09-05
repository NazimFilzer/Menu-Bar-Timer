import SwiftUI

enum DashboardTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case analytics = "Analytics"
    case settings = "Settings"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .analytics: return "chart.bar.xaxis"
        case .settings: return "gearshape.fill"
        }
    }
}

enum DashboardSubTab: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }
}

struct DashboardView: View {
    @Bindable var vm: TimerViewModel
    @State private var selectedTab: DashboardTab = .dashboard
    @State private var selectedSubTab: DashboardSubTab = .week
    @State private var themeManager = ThemeManager.shared

    private var theme: PopoverTheme { themeManager.theme }

    var body: some View {
        VStack(spacing: 0) {
            // Unified Top Toolbar
            DashboardTopToolbar(
                selectedTab: $selectedTab,
                vm: vm,
                theme: theme
            )

            Divider().background(theme.dividerColor)

            // Content Area
            ZStack {
                theme.bgDark.ignoresSafeArea()

                switch selectedTab {
                case .dashboard:
                    DashboardHomeContainer(
                        vm: vm,
                        selectedSubTab: $selectedSubTab,
                        theme: theme
                    )
                case .analytics:
                    AnalyticsDashboardView(
                        vm: vm,
                        theme: theme
                    )
                case .settings:
                    DashboardSettingsView(
                        vm: vm,
                        theme: theme
                    )
                }
            }
        }
        .frame(minWidth: 800, minHeight: 550)
        .preferredColorScheme(theme.isLight ? .light : .dark)
    }
}

// MARK: - Top Toolbar

private struct DashboardTopToolbar: View {
    @Binding var selectedTab: DashboardTab
    let vm: TimerViewModel
    let theme: PopoverTheme

    private var dotColor: Color {
        theme.statusColor(for: vm.state)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left Branding
            HStack(spacing: 7) {
                Text("SKEVAL TIMER")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                    .kerning(1.2)

                Text("v2")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(theme.neonTeal.opacity(0.2))
                    .foregroundColor(theme.neonTeal)
                    .clipShape(Capsule())
            }

            Spacer()

            // Centered Segmented Navigation
            HStack(spacing: 4) {
                ForEach(DashboardTab.allCases) { tab in
                    let isSelected = selectedTab == tab
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 11))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(isSelected ? theme.neonTeal.opacity(0.18) : Color.clear)
                        .foregroundColor(isSelected ? theme.neonTeal : theme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? theme.neonTeal.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(theme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.cardBorder, lineWidth: 1))

            Spacer()

            // Right Status & Quick Timer Pill
            HStack(spacing: 8) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: dotColor.opacity(0.8), radius: vm.isRunning ? 6 : 0)

                Text(vm.statusTitle)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(dotColor)

                if vm.isRunning {
                    Text(vm.currentElapsedLabel)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)

                    if let tag = vm.currentTag, !tag.isEmpty {
                        Text("#\(tag)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.neonTeal.opacity(0.18))
                            .foregroundColor(theme.neonTeal)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(theme.cardBg)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(theme.cardBorder, lineWidth: 1))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(theme.cardBg.opacity(0.7))
    }
}

// MARK: - Dashboard Home Sub-Container (Week / Month)

private struct DashboardHomeContainer: View {
    @Bindable var vm: TimerViewModel
    @Binding var selectedSubTab: DashboardSubTab
    let theme: PopoverTheme

    var body: some View {
        VStack(spacing: 0) {
            // Sub-navigation bar [ Week | Month ]
            HStack {
                HStack(spacing: 4) {
                    ForEach(DashboardSubTab.allCases) { subTab in
                        let isSelected = selectedSubTab == subTab
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedSubTab = subTab
                            }
                        }) {
                            Text(subTab.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4.5)
                                .background(isSelected ? theme.neonTeal.opacity(0.2) : Color.clear)
                                .foregroundColor(isSelected ? theme.neonTeal : theme.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(theme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(theme.cardBorder, lineWidth: 1))

                Spacer()

                // Currency / Hourly Rate summary
                HStack(spacing: 6) {
                    Text("Hourly Rate:")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                    Text(EarningsCalculator.format(amount: vm.goal.hourlyRate, currencySymbol: vm.goal.currencySymbol) + "/hr")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.neonTeal)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(theme.cardBg.opacity(0.6))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider().background(theme.dividerColor)

            // Dynamic view based on Week / Month
            ScrollView {
                VStack(spacing: 20) {
                    if selectedSubTab == .week {
                        WeeklyDashboardView(vm: vm, theme: theme)
                    } else {
                        MonthlyDashboardView(vm: vm, theme: theme)
                    }
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Reusable Dashboard Metric Card

struct MetricCardView: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let theme: PopoverTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .kerning(0.8)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(theme.neonTeal)
            }

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textPrimary)

            Text(subtitle)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder, lineWidth: 1))
    }
}
