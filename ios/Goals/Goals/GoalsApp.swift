import SwiftUI

@main
struct GoalsApp: App {
    @State private var store = GoalStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.locale, Locale(identifier: "he_IL"))
                .environment(\.layoutDirection, .rightToLeft)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.refreshDay() }
                }
        }
    }
}

/// Functional layer: the system tab bar (Liquid Glass), minimizing on scroll.
struct RootView: View {
    var body: some View {
        TabView {
            Tab("היום", systemImage: "checkmark.circle") {
                NavigationStack { TodayView() }
            }
            Tab("היסטוריה", systemImage: "square.grid.3x3.fill") {
                NavigationStack { HistoryView() }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
