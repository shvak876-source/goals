import SwiftUI

/// Sheet for a new goal or editing one. The sheet itself is system Liquid Glass.
struct GoalEditor: View {
    @Environment(GoalStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let editingID: Goal.ID?
    @State private var text: String
    @State private var subs: [EditableSub]
    @State private var repeats: Bool
    @FocusState private var focus: Field?

    private enum Field: Hashable { case title, sub(UUID) }

    private struct EditableSub: Identifiable, Hashable {
        var id = UUID()
        var text: String
    }

    init(initialText: String = "") {
        editingID = nil
        _text = State(initialValue: initialText)
        _subs = State(initialValue: [])
        _repeats = State(initialValue: false)
    }

    init(editing goal: Goal) {
        editingID = goal.id
        _text = State(initialValue: goal.text)
        _subs = State(initialValue: goal.subs.map { EditableSub(text: $0.text) })
        _repeats = State(initialValue: goal.repeats)
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("מה המטרה?", text: $text)
                        .font(.title3.weight(.semibold))
                        .focused($focus, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { addSub() }
                }

                Section("תתי־מטרות") {
                    ForEach($subs) { $sub in
                        HStack {
                            Image(systemName: "circle")
                                .foregroundStyle(.tertiary)
                            TextField("תת־מטרה", text: $sub.text)
                                .focused($focus, equals: .sub(sub.id))
                                .submitLabel(.next)
                                .onSubmit { addSub() }
                        }
                    }
                    .onDelete { subs.remove(atOffsets: $0) }
                    .onMove { subs.move(fromOffsets: $0, toOffset: $1) }

                    Button("הוספת תת־מטרה", systemImage: "plus.circle.fill", action: addSub)
                }

                Section {
                    Toggle(isOn: $repeats) {
                        Label("חוזרת כל יום", systemImage: "repeat")
                    }
                } footer: {
                    Text("מטרה חוזרת תופיע אוטומטית ברשימה בכל בוקר.")
                }
            }
            .scrollContentBackground(.hidden)          // let the sheet's glass show
            .navigationTitle(editingID == nil ? "מטרה חדשה" : "עריכת מטרה")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ביטול", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingID == nil ? "הוספה" : "שמירה", action: save)
                        .buttonStyle(.glassProminent)
                        .disabled(trimmed.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { focus = .title }
    }

    private func addSub() {
        if let last = subs.last, last.text.trimmingCharacters(in: .whitespaces).isEmpty {
            focus = .sub(last.id)
            return
        }
        let new = EditableSub(text: "")
        subs.append(new)
        focus = .sub(new.id)
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        let subTexts = subs.map { $0.text.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        withAnimation(.snappy) {
            if let id = editingID {
                store.updateGoal(id, text: trimmed, subs: subTexts, repeats: repeats)
            } else {
                store.addGoal(text: trimmed, subs: subTexts, repeats: repeats)
            }
        }
        dismiss()
    }
}

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("name") private var name = "שלמה"
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("איך לקרוא לך?") {
                    TextField("השם שלך", text: $draft)
                        .submitLabel(.done)
                        .onSubmit(save)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("הגדרות")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ביטול", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("שמירה", action: save)
                        .buttonStyle(.glassProminent)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { draft = name }
    }

    private func save() {
        name = draft.trimmingCharacters(in: .whitespaces)
        dismiss()
    }
}
