import SwiftUI

// Content layer (no glass): the summary card and the goal list.
// Functional layer (glass): the navigation bar (system) and the quick-add
// composer pinned above the tab bar, which morphs inside one GlassEffectContainer.

struct TodayView: View {
    @Environment(GoalStore.self) private var store
    @AppStorage("name") private var name = "שלמה"

    @State private var collapsed: Set<Goal.ID> = []
    @State private var route: SheetRoute?
    @State private var draft = ""
    @State private var subDrafts: [Goal.ID: String] = [:]
    @State private var confirmDelete: Goal?
    @FocusState private var composerFocused: Bool
    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let goals = store.todayGoals
        let stats = store.stats(for: store.todayKey)

        List {
            Section {
                SummaryCard(stats: stats, streak: store.streaks.current)
                    .listRowInsets(EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18))
            }

            if goals.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("יום חדש, דף חלק", systemImage: "scope")
                    } description: {
                        Text("כתוב מטרה בשורה שלמטה כדי להתחיל")
                    }
                }
                .listRowBackground(Color.clear)
            }

            ForEach(goals) { goal in
                Section {
                    goalRow(goal)
                    if !goal.subs.isEmpty && !collapsed.contains(goal.id) {
                        ForEach(goal.subs) { sub in
                            subRow(sub, in: goal)
                        }
                        addSubRow(goal)
                    }
                }
            }

            if store.showsExamples {
                Section {
                    Button("אלה מטרות לדוגמה. לנקות הכול") {
                        withAnimation { store.clearExamples() }
                    }
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listSectionSpacing(10)
        .animation(.snappy, value: goals)
        .navigationTitle(greeting)
        .navigationSubtitle(dateLine)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("הגדרות", systemImage: "person.crop.circle") { route = .settings }
            }
        }
        .safeAreaInset(edge: .bottom) {
            composer
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .sensoryFeedback(.success, trigger: stats.isComplete) { _, now in now }
        .sheet(item: $route) { route in
            switch route {
            case .add(let text):
                GoalEditor(initialText: text)
            case .edit(let goal):
                GoalEditor(editing: goal)
            case .settings:
                SettingsSheet()
            }
        }
        .confirmationDialog(
            "המטרה חוזרת כל יום",
            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
            titleVisibility: .visible,
            presenting: confirmDelete
        ) { goal in
            Button("מחיקה מהיום בלבד", role: .destructive) { withAnimation { store.delete(goal.id) } }
            Button("מחיקה והפסקת החזרה", role: .destructive) { withAnimation { store.delete(goal.id, stopRepeating: true) } }
            Button("ביטול", role: .cancel) { }
        }
    }

    // MARK: Header text

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let hello: String
        switch hour {
        case 5..<12: hello = "בוקר טוב"
        case 12..<17: hello = "צהריים טובים"
        case 17..<22: hello = "ערב טוב"
        default: hello = "לילה טוב"
        }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? hello : "\(hello), \(trimmed)"
    }

    private var dateLine: String {
        let he = Locale(identifier: "he_IL")
        let gregorian = Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(he))
        let hebrew = Date.now.formatted(
            Date.FormatStyle(date: .long, time: .omitted, locale: he, calendar: Calendar(identifier: .hebrew))
        )
        return "\(gregorian) · \(hebrew)"
    }

    // MARK: Rows

    private func goalRow(_ goal: Goal) -> some View {
        HStack(spacing: 12) {
            CheckCircle(isOn: goal.isComplete, size: 28) {
                withAnimation(.snappy) { store.toggle(goal.id) }
            }
            .accessibilityLabel(goal.text)

            Button {
                if goal.subs.isEmpty {
                    withAnimation(.snappy) { store.toggle(goal.id) }
                } else {
                    withAnimation(.snappy) {
                        if collapsed.contains(goal.id) { collapsed.remove(goal.id) } else { collapsed.insert(goal.id) }
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.text)
                        .font(.body.weight(.semibold))
                        .strikethrough(goal.isComplete)
                        .foregroundStyle(goal.isComplete ? .secondary : .primary)
                    if !goal.subs.isEmpty || goal.repeats {
                        HStack(spacing: 10) {
                            if !goal.subs.isEmpty {
                                Label("\(goal.subs.filter(\.done).count)/\(goal.subs.count)", systemImage: "list.bullet")
                            }
                            if goal.repeats {
                                Label("כל יום", systemImage: "repeat")
                            }
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .labelStyle(CompactLabelStyle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if !goal.subs.isEmpty {
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(collapsed.contains(goal.id) ? 0 : 180))
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("מחיקה", systemImage: "trash", role: .destructive) { requestDelete(goal) }
        }
        .swipeActions(edge: .leading) {
            Button("עריכה", systemImage: "pencil") { route = .edit(goal) }
                .tint(.blue)
        }
        .contextMenu {
            Button("עריכה", systemImage: "pencil") { route = .edit(goal) }
            Button(goal.repeats ? "הפסקת חזרה יומית" : "חזרה כל יום", systemImage: "repeat") {
                store.setRepeats(goal.id, !goal.repeats)
            }
            Divider()
            Button("מחיקה", systemImage: "trash", role: .destructive) { requestDelete(goal) }
        }
    }

    private func subRow(_ sub: SubGoal, in goal: Goal) -> some View {
        HStack(spacing: 12) {
            CheckCircle(isOn: sub.done, size: 22) {
                withAnimation(.snappy) { store.toggleSub(sub.id, in: goal.id) }
            }
            .accessibilityLabel(sub.text)
            Text(sub.text)
                .strikethrough(sub.done)
                .foregroundStyle(sub.done ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 20)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("מחיקה", systemImage: "trash", role: .destructive) {
                withAnimation { store.deleteSub(sub.id, from: goal.id) }
            }
        }
    }

    private func addSubRow(_ goal: Goal) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 22)
            TextField("תת־מטרה חדשה", text: Binding(
                get: { subDrafts[goal.id, default: ""] },
                set: { subDrafts[goal.id] = $0 }
            ))
            .submitLabel(.done)
            .onSubmit {
                let text = subDrafts[goal.id, default: ""].trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { return }
                withAnimation { store.addSub(text, to: goal.id) }
                subDrafts[goal.id] = ""
            }
        }
        .padding(.leading, 20)
    }

    private func requestDelete(_ goal: Goal) {
        if goal.repeats {
            confirmDelete = goal
        } else {
            withAnimation { store.delete(goal.id) }
        }
    }

    // MARK: Composer (functional layer: custom glass)

    private var composer: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                TextField("מטרה חדשה…", text: $draft)
                    .focused($composerFocused)
                    .submitLabel(.done)
                    .onSubmit(quickAdd)
                    .padding(.horizontal, 18)
                    .frame(height: 50)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .glassEffectID("field", in: ns)

                Button {
                    if draft.trimmingCharacters(in: .whitespaces).isEmpty {
                        composerFocused = false
                        route = .add("")
                    } else {
                        quickAdd()
                    }
                } label: {
                    Image(systemName: draft.isEmpty ? "plus" : "arrow.up")
                        .contentTransition(.symbolEffect(.replace))
                        .font(.title3.weight(.bold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .accessibilityLabel(draft.isEmpty ? "מטרה חדשה עם תתי־מטרות" : "הוספה")
                .glassEffectID("add", in: ns)

                if composerFocused && !draft.isEmpty {
                    Button {
                        route = .add(draft)
                        draft = ""
                        composerFocused = false
                    } label: {
                        Image(systemName: "list.bullet.indent")
                            .font(.title3.weight(.semibold))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .tint(.primary)
                    .accessibilityLabel("פרטים ותתי־מטרות")
                    .glassEffectID("more", in: ns)
                }
            }
        }
        .animation(reduceMotion ? .smooth : .bouncy, value: composerFocused && !draft.isEmpty)
        .animation(.snappy, value: draft.isEmpty)
    }

    private func quickAdd() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        withAnimation(.snappy) { store.addGoal(text: text, subs: [], repeats: false) }
        draft = ""
    }
}

// MARK: - Sheet routing

enum SheetRoute: Identifiable {
    case add(String)
    case edit(Goal)
    case settings

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let g): "edit-\(g.id)"
        case .settings: "settings"
        }
    }
}

// MARK: - Summary card (content layer)

struct SummaryCard: View {
    let stats: DayStats
    let streak: Int

    var body: some View {
        HStack(spacing: 18) {
            ProgressRing(progress: stats.ratio)
                .frame(width: 100, height: 100)
                .overlay {
                    VStack(spacing: 0) {
                        Text(stats.ratio, format: .percent.precision(.fractionLength(0)))
                            .font(.title2.weight(.heavy))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: stats.ratio))
                        Text("הושלם")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .scaleEffect(stats.isComplete ? 1.04 : 1)
                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: stats.isComplete)
                .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(streakText, systemImage: "flame.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.tint.opacity(0.14), in: .capsule)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var title: String {
        if stats.total == 0 { return "עוד אין מטרות להיום" }
        if stats.isComplete { return "השלמת הכול!" }
        let left = stats.total - stats.done
        return left == 1 ? "נשארה מטרה אחת" : "נשארו \(left) מטרות"
    }

    private var subtitle: String {
        stats.total == 0 ? "הוסף את הראשונה בשורה שלמטה" : "\(stats.done) מתוך \(stats.total) הושלמו"
    }

    private var streakText: String {
        switch streak {
        case 0: "מתחילים רצף היום"
        case 1: "יום אחד ברצף"
        default: "\(streak) ימים ברצף"
        }
    }
}

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 13

    var body: some View {
        ZStack {
            Circle()
                .stroke(.tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(progress, 0.001))
                .stroke(
                    AngularGradient(colors: [.ringStart, .accentColor], center: .center,
                                    startAngle: .degrees(0), endAngle: .degrees(360 * max(progress, 0.01))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(progress > 0 ? 1 : 0)
                .animation(.spring(response: 0.7, dampingFraction: 0.8), value: progress)
        }
        .environment(\.layoutDirection, .leftToRight)   // the ring always fills clockwise
    }
}

// MARK: - Circular check

struct CheckCircle: View {
    let isOn: Bool
    var size: CGFloat = 28
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .resizable()
                .fontWeight(.medium)
                .frame(width: size, height: size)
                .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isOn)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}

extension Color {
    static let ringStart = Color(red: 0.62, green: 0.89, blue: 0.27)
}
