import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max.fill") {
                TodayView()
            }
            Tab("Food", systemImage: "magnifyingglass") {
                FoodView()
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                ProgressScreen()
            }
            Tab("Supplements", systemImage: "pills.fill") {
                SupplementsView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
    }
}
