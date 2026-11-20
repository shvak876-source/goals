import Foundation
import Observation

// MARK: - Model

struct SubGoal: Identifiable, Codable, Hashable {
    var id = UUID()
    var text: String
    var done = false
}

struct Goal: Identifiable, Codable, Hashable {
    var id = UUID()
    var text: String
    var done = false
    var subs: [SubGoal] = []
    /// Set when the goal repeats every day.
    var templateID: UUID?

    /// A goal with subgoals is complete when all of them are.
    var isComplete: Bool { subs.isEmpty ? done : subs.allSatisfy(\.done) }
    var repeats: Bool { templateID != nil }
}

struct GoalTemplate: Identifiable, Codable, Hashable {
    var id = UUID()
    var text: String
    var subs: [String]
}

struct DayRecord: Codable, Hashable {
    var goals: [Goal] = []
}

struct DayStats {
    var total = 0
    var done = 0
    var ratio: Double { total == 0 ? 0 : Double(done) / Double(total) }
    var isComplete: Bool { total > 0 && done == total }
}

struct StreakStats {
    var current = 0
    var best = 0
    var perfectDays = 0
    var goalsCompleted = 0
}

// MARK: - Store

@Observable
final class GoalStore {
    private(set) var days: [String: DayRecord] = [:]
    private(set) var templates: [GoalTemplate] = []
    var showsExamples = false
    private(set) var todayKey: String = DayKey.string(from: .now)

    private struct Snapshot: Codable {
        var days: [String: DayRecord]
        var templates: [GoalTemplate]
        var showsExamples: Bool
    }

    private let url: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("goals.json")
    }()

    init() {
        if let data = try? Data(contentsOf: url),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            days = snap.days
            templates = snap.templates
            showsExamples = snap.showsExamples
        } else {
            days[todayKey] = DayRecord(goals: [
                Goal(text: "לשתות 8 כוסות מים"),
                Goal(text: "אימון בוקר", subs: [
                    SubGoal(text: "חימום 5 דקות"),
                    SubGoal(text: "ריצה 20 דקות"),
                    SubGoal(text: "מתיחות"),
                ]),
                Goal(text: "לקרוא 20 עמודים"),
            ])
            showsExamples = true
        }
        refreshDay()
    }

    private func save() {
        let snap = Snapshot(days: days, templates: templates, showsExamples: showsExamples)
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Call on launch and whenever the app comes back to the foreground.
    func refreshDay() {
        todayKey = DayKey.string(from: .now)
        if days[todayKey] == nil {
            days[todayKey] = DayRecord(goals: templates.map { t in
                Goal(text: t.text, subs: t.subs.map { SubGoal(text: $0) }, templateID: t.id)
            })
            save()
        }
    }

    // MARK: Today

    var todayGoals: [Goal] { days[todayKey]?.goals ?? [] }

    private func updateToday(_ change: (inout [Goal]) -> Void) {
        var record = days[todayKey] ?? DayRecord()
        change(&record.goals)
        days[todayKey] = record
        save()
    }

    func toggle(_ goalID: Goal.ID) {
        updateToday { goals in
            guard let i = goals.firstIndex(where: { $0.id == goalID }) else { return }
            let newValue = !goals[i].isComplete
            goals[i].done = newValue
            for j in goals[i].subs.indices { goals[i].subs[j].done = newValue }
        }
    }

    func toggleSub(_ subID: SubGoal.ID, in goalID: Goal.ID) {
        updateToday { goals in
            guard let i = goals.firstIndex(where: { $0.id == goalID }),
                  let j = goals[i].subs.firstIndex(where: { $0.id == subID }) else { return }
            goals[i].subs[j].done.toggle()
            goals[i].done = goals[i].isComplete
        }
    }

    func addGoal(text: String, subs: [String], repeats: Bool) {
        var goal = Goal(text: text, subs: subs.map { SubGoal(text: $0) })
        if repeats {
            let t = GoalTemplate(text: text, subs: subs)
            templates.append(t)
            goal.templateID = t.id
        }
        showsExamples = false
        updateToday { $0.append(goal) }
    }

    func updateGoal(_ goalID: Goal.ID, text: String, subs: [String], repeats: Bool) {
        updateToday { goals in
            guard let i = goals.firstIndex(where: { $0.id == goalID }) else { return }
            let old = goals[i].subs
            goals[i].text = text
            goals[i].subs = subs.map { s in old.first(where: { $0.text == s }) ?? SubGoal(text: s) }
            if !goals[i].subs.isEmpty { goals[i].done = goals[i].isComplete }
            setRepeat(&goals[i], repeats)
            syncTemplate(goals[i])
        }
    }

    func addSub(_ text: String, to goalID: Goal.ID) {
        updateToday { goals in
            guard let i = goals.firstIndex(where: { $0.id == goalID }) else { return }
            goals[i].subs.append(SubGoal(text: text))
            goals[i].done = goals[i].isComplete
            syncTemplate(goals[i])
        }
    }

    func deleteSub(_ subID: SubGoal.ID, from goalID: Goal.ID) {
        updateToday { goals in
            guard let i = goals.firstIndex(where: { $0.id == goalID }) else { return }
            goals[i].subs.removeAll { $0.id == subID }
            syncTemplate(goals[i])
        }
    }

    func setRepeats(_ goalID: Goal.ID, _ on: Bool) {
        updateToday { goals in
            guard let i = goals.firstIndex(where: { $0.id == goalID }) else { return }
            setRepeat(&goals[i], on)
        }
    }

    func delete(_ goalID: Goal.ID, stopRepeating: Bool = false) {
        updateToday { goals in
            if stopRepeating, let g = goals.first(where: { $0.id == goalID }), let tid = g.templateID {
                templates.removeAll { $0.id == tid }
            }
            goals.removeAll { $0.id == goalID }
        }
        if todayGoals.isEmpty { showsExamples = false; save() }
    }

    func clearExamples() {
        showsExamples = false
        updateToday { $0.removeAll() }
    }

    private func setRepeat(_ goal: inout Goal, _ on: Bool) {
        if on, goal.templateID == nil {
            let t = GoalTemplate(text: goal.text, subs: goal.subs.map(\.text))
            templates.append(t)
            goal.templateID = t.id
        } else if !on, let tid = goal.templateID {
            templates.removeAll { $0.id == tid }
            goal.templateID = nil
        }
    }

    private func syncTemplate(_ goal: Goal) {
        guard let tid = goal.templateID, let i = templates.firstIndex(where: { $0.id == tid }) else { return }
        templates[i].text = goal.text
        templates[i].subs = goal.subs.map(\.text)
    }

    // MARK: History

    func stats(for key: String) -> DayStats {
        guard let goals = days[key]?.goals, !goals.isEmpty else { return DayStats() }
        return DayStats(total: goals.count, done: goals.filter(\.isComplete).count)
    }

    func stats(for date: Date) -> DayStats { stats(for: DayKey.string(from: date)) }

    var streaks: StreakStats {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var result = StreakStats()

        var day = stats(for: today).isComplete ? today : cal.date(byAdding: .day, value: -1, to: today)!
        while stats(for: day).isComplete {
            result.current += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }

        guard let firstKey = days.keys.min(), var cursor = DayKey.date(from: firstKey) else { return result }
        var run = 0
        while cursor <= today {
            let s = stats(for: cursor)
            result.goalsCompleted += s.done
            if s.isComplete {
                run += 1
                result.perfectDays += 1
                result.best = max(result.best, run)
            } else {
                run = 0
            }
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        return result
    }
}

// MARK: - Day keys

enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func string(from date: Date) -> String { formatter.string(from: date) }
    static func date(from key: String) -> Date? { formatter.date(from: key) }
}
