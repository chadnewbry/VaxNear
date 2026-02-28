import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            FinderView()
                .tabItem {
                    Label("Find", systemImage: "mappin.and.ellipse")
                }

            RecordsView()
                .tabItem {
                    Label("Records", systemImage: "list.clipboard")
                }

            TravelView()
                .tabItem {
                    Label("Travel", systemImage: "airplane")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(.accentColor)
    }
}

#Preview {
    MainTabView()
}
