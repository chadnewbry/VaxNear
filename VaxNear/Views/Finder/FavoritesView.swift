import MapKit
import SwiftData
import SwiftUI

struct FavoritesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<SavedLocation> { $0.isFavorite },
           sort: \SavedLocation.name)
    private var favorites: [SavedLocation]

    var body: some View {
        NavigationStack {
            Group {
                if favorites.isEmpty {
                    ContentUnavailableView {
                        Label("No Favorites", systemImage: "heart.slash")
                    } description: {
                        Text("Tap the heart icon on any vaccination site to save it here.")
                    }
                } else {
                    List {
                        ForEach(favorites) { loc in
                            NavigationLink(value: loc) {
                                FavoriteRow(location: loc)
                            }
                            .accessibilityLabel("\(loc.name), \(loc.address)")
                            .accessibilityHint("Tap to view site details")
                        }
                        .onDelete(perform: deleteFavorites)
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SavedLocation.self) { loc in
                SavedLocationDetailView(location: loc)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                if !favorites.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
            }
        }
    }

    private func deleteFavorites(at offsets: IndexSet) {
        for index in offsets {
            favorites[index].isFavorite = false
        }
        try? modelContext.save()
    }
}

// MARK: - Favorite Row

private struct FavoriteRow: View {
    let location: SavedLocation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(location.name)
                .font(.subheadline.weight(.semibold))

            Text(location.address)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if let phone = location.phoneNumber {
                    Label(phone, systemImage: "phone")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if location.isWalkIn {
                    Label("Walk-in", systemImage: "figure.walk")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }

            if !location.vaccineTypesAvailable.isEmpty {
                HStack(spacing: 4) {
                    ForEach(location.vaccineTypesAvailable.prefix(3), id: \.self) { vaccine in
                        Text(vaccine)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                    if location.vaccineTypesAvailable.count > 3 {
                        Text("+\(location.vaccineTypesAvailable.count - 3)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    FavoritesView()
        .modelContainer(for: SavedLocation.self, inMemory: true)
}
