import SwiftData
import SwiftUI

/// A reusable upgrade banner that can be placed in any view to prompt free users to upgrade.
/// Automatically hides when the user has purchased the full version.
struct UpgradeBannerView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var storeManager = StoreKitManager.shared
    @State private var showingPaywall = false

    let style: BannerStyle

    enum BannerStyle {
        case compact    // Single-line with arrow
        case prominent  // Card with icon and description
        case inline     // Subtle inline text with button
    }

    init(style: BannerStyle = .prominent) {
        self.style = style
    }

    private var settings: AppSettings {
        AppSettings.shared(in: modelContext)
    }

    var body: some View {
        if !settings.hasPurchasedFullVersion {
            Group {
                switch style {
                case .compact:
                    compactBanner
                case .prominent:
                    prominentBanner
                case .inline:
                    inlineBanner
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView {
                    storeManager.syncSettingsIfNeeded(context: modelContext)
                }
            }
            .onChange(of: storeManager.isPurchased) { _, purchased in
                if purchased {
                    storeManager.syncSettingsIfNeeded(context: modelContext)
                }
            }
        }
    }

    // MARK: - Compact

    private var compactBanner: some View {
        Button { showingPaywall = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                Text("Unlock all features")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(storeManager.fullVersionProduct?.displayPrice ?? "$4.99")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Prominent

    private var prominentBanner: some View {
        Button { showingPaywall = true } label: {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        Image(systemName: "syringe.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upgrade to VaxNear Full")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text("Unlimited records, family profiles, travel planning & more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }

                HStack {
                    Text("One-time purchase · \(storeManager.fullVersionProduct?.displayPrice ?? "$4.99")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Upgrade")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .task { await storeManager.loadProducts() }
    }

    // MARK: - Inline

    private var inlineBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Premium feature")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Upgrade") {
                showingPaywall = true
            }
            .font(.caption.bold())
        }
    }
}

#Preview("Prominent") {
    UpgradeBannerView(style: .prominent)
        .padding()
}

#Preview("Compact") {
    UpgradeBannerView(style: .compact)
        .padding()
}
