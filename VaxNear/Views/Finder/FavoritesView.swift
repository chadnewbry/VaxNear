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
                            VStack(alignment: .leading, spacing: 4) {
                                Text(loc.name)
                                    .font(.subheadline.weight(.medium))
                                Text(loc.address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let phone = loc.phoneNumber {
                                    Label(phone, systemImage: "phone")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .accessibilityLabel("Phone: \(phone)")
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete(perform: deleteFavorites)
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func deleteFavorites(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(favorites[index])
        }
        try? modelContext.save()
    }
}

#Preview {
    FavoritesView()
        .modelContainer(for: SavedLocation.self, inMemory: true)
}
