import SwiftUI

// Content layer only (cards and the heatmap: no glass). The navigation bar,
// tab bar and the day sheet are the system's Liquid Glass.

struct HistoryView: View {
    @Environment(GoalStore.self) private var store
    @State private var selectedDay: SelectedDay?

    private let weeks = 16
    private let cell: CGFloat = 13

    var body: some View {
        let streak = store.streaks

        ScrollView {
            VStack(spacing: 14) {
                streakHero(streak)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    StatTile(value: streak.best, unit: "ימים", label: "שיא רצף")
                    StatTile(value: streak.perfectDays, unit: nil, label: "ימים מושלמים")
                }
                StatTile(value: streak.goalsCompleted, unit: nil, label: "מטרות שהושלמו בסך הכול")

                heatmapCard
                lastWeekCard
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("היסטוריה")
        .sheet(item: $selectedDay) { day in
            DayDetailSheet(key: day.id)
        }
    }

    // MARK: Streak

    private func streakHero(_ s: StreakStats) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(s.current, format: .number)
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText(value: Double(s.current)))
                    Text(s.current == 1 ? "יום" : "ימים")
                        .font(.title3.weight(.bold))
                }
                Text("ברצף שאני עומד במטרות")
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
            Image(systemName: "flame.fill")
                .font(.system(size: 54))
                .symbolEffect(.bounce, value: s.current)
                .accessibilityHidden(true)
        }
        .foregroundStyle(.black.opacity(0.82))
        .padding(20)
        .background(
            LinearGradient(colors: [.ringStart, .accentColor], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: 26, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: Heatmap

    private var heatmapCard: some View {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: .now)
        let weekday = cal.component(.weekday, from: today) - 1          // Sunday = 0
        let start = cal.date(byAdding: .day, value: -weekday - (weeks - 1) * 7, to: today)!
        let todayKey = DayKey.string(from: today)
        let monthFormat = Date.FormatStyle.dateTime.month(.abbreviated).locale(Locale(identifier: "he_IL"))

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("ימים שהשלמתי").font(.headline)
                Spacer()
                Text("\(weeks) שבועות").font(.footnote).foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 6) {
                VStack(spacing: 4) {
                    Color.clear.frame(height: 14)
                    ForEach(Array(["א׳", "", "ג׳", "", "ה׳", "", "ש׳"].enumerated()), id: \.offset) { _, d in
                        Text(d).font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                            .frame(height: cell)
                    }
                }

                HStack(alignment: .top, spacing: 4) {
                        ForEach(0..<weeks, id: \.self) { w in
                            let first = cal.date(byAdding: .day, value: w * 7, to: start)!
                            let prev = cal.date(byAdding: .day, value: -7, to: first)!
                            let newMonth = w == 0 || cal.component(.month, from: first) != cal.component(.month, from: prev)
                            VStack(spacing: 4) {
                                Text(newMonth ? first.formatted(monthFormat) : "")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                    .fixedSize()
                                    .frame(width: cell, height: 14, alignment: .leading)
                                ForEach(0..<7, id: \.self) { d in
                                    let day = cal.date(byAdding: .day, value: w * 7 + d, to: start)!
                                    let key = DayKey.string(from: day)
                                    if day > today {
                                        Color.clear.frame(width: cell, height: cell)
                                    } else {
                                        Button { selectedDay = SelectedDay(id: key) } label: {
                                            HeatCell(stats: store.stats(for: key), isToday: key == todayKey, size: cell)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                                        .accessibilityValue("\(store.stats(for: key).done) מתוך \(store.stats(for: key).total)")
                                    }
                                }
                            }
                        }
                }
            }

            HStack(spacing: 4) {
                Spacer()
                Text("פחות")
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(HeatCell.color(level))
                        .frame(width: 12, height: 12)
                }
                Text("יותר")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .card()
    }

    // MARK: Last 7 days

    private var lastWeekCard: some View {
        let cal = Calendar.current
        let dayFormat = Date.FormatStyle.dateTime.weekday(.abbreviated).day().locale(Locale(identifier: "he_IL"))
        return VStack(alignment: .leading, spacing: 12) {
            Text("7 הימים האחרונים").font(.headline)
            ForEach(0..<7, id: \.self) { i in
                let day = cal.date(byAdding: .day, value: -i, to: .now)!
                let s = store.stats(for: day)
                HStack(spacing: 10) {
                    Text(i == 0 ? "היום" : i == 1 ? "אתמול" : day.formatted(dayFormat))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .leading)
                    ProgressView(value: s.ratio)
                        .tint(s.isComplete ? Color.accentColor : Color.accentColor.opacity(0.7))
                    Text(s.total == 0 ? "—" : "\(s.done)/\(s.total)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(s.isComplete ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .card()
    }
}

struct SelectedDay: Identifiable { let id: String }

struct HeatCell: View {
    let stats: DayStats
    let isToday: Bool
    var size: CGFloat = 13

    static func color(_ level: Int) -> Color {
        switch level {
        case 0: Color(.tertiarySystemFill)
        case 1: Color.accentColor.opacity(0.25)
        case 2: Color.accentColor.opacity(0.5)
        case 3: Color.accentColor.opacity(0.75)
        default: Color.accentColor
        }
    }

    private var level: Int {
        guard stats.total > 0, stats.done > 0 else { return 0 }
        if stats.isComplete { return 4 }
        return stats.ratio >= 0.66 ? 3 : stats.ratio >= 0.33 ? 2 : 1
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Self.color(level))
            .frame(width: size, height: size)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(.primary, lineWidth: 1.5)
                }
            }
    }
}

struct StatTile: View {
    let value: Int
    let unit: String?
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value, format: .number)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                if let unit {
                    Text(unit).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            Text(label).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Content-layer card: a solid grouped fill, not glass.
    func card() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Day detail sheet

struct DayDetailSheet: View {
    @Environment(GoalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let key: String

    var body: some View {
        let date = DayKey.date(from: key) ?? .now
        let s = store.stats(for: key)
        let goals = store.days[key]?.goals ?? []

        NavigationStack {
            List {
                Section {
                    Text(summary(s))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)

                ForEach(goals) { goal in
                    Section {
                        row(goal.text, done: goal.isComplete, bold: true)
                        ForEach(goal.subs) { sub in
                            row(sub.text, done: sub.done, bold: false)
                                .padding(.leading, 24)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "he_IL"))))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func summary(_ s: DayStats) -> String {
        if s.total == 0 { return "לא נרשמו מטרות ביום הזה" }
        if s.isComplete { return "השלמת את כל \(s.total) המטרות" }
        return "\(s.done) מתוך \(s.total) מטרות הושלמו"
    }

    private func row(_ text: String, done: Bool, bold: Bool) -> some View {
        Label {
            Text(text)
                .fontWeight(bold ? .semibold : .regular)
                .strikethrough(done)
                .foregroundStyle(done ? .secondary : .primary)
        } icon: {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
        }
    }
}
