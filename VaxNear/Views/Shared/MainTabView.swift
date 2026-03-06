import SwiftUI

struct MainTabView: View {
    @StateObject private var navigationState = NavigationState.shared
    @StateObject private var finderVM = FinderViewModel()

    var body: some View {
        TabView(selection: $navigationState.selectedTab) {
            FinderView(vm: finderVM)
                .tabItem {
                    Label("Find", systemImage: "mappin.and.ellipse")
                }
                .accessibilityLabel("Find vaccination sites")
                .tag(AppTab.finder)

            RecordsView()
                .tabItem {
                    Label("Records", systemImage: "list.clipboard")
                }
                .accessibilityLabel("Vaccination records")
                .tag(AppTab.records)

            FamilyProfilesView()
                .tabItem {
                    Label("Family", systemImage: "person.3")
                }
                .accessibilityLabel("Family profiles")
                .tag(AppTab.family)

            TravelView()
                .tabItem {
                    Label("Travel", systemImage: "airplane")
                }
                .accessibilityLabel("Travel vaccine planning")
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
