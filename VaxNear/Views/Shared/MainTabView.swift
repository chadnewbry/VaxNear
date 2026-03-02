import SwiftUI

struct MainTabView: View {
    @StateObject private var navigationState = NavigationState.shared

    var body: some View {
        TabView(selection: $navigationState.selectedTab) {
            FinderView()
                .tabItem {
                    Label("Find", systemImage: "mappin.and.ellipse")
                }
                .tag(AppTab.finder)

            RecordsView()
                .tabItem {
                    Label("Records", systemImage: "list.clipboard")
                }
                .tag(AppTab.records)

            TravelView()
                .tabItem {
                    Label("Travel", systemImage: "airplane")
                }
                .tag(AppTab.travel)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(.accentColor)
    }
}

#Preview {
    MainTabView()
}
