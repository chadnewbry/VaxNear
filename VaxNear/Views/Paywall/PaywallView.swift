import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreKitManager.shared
    @State private var showRestoreAlert = false
    @State private var restoreSuccess = false

    var onPurchaseComplete: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "syringe.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)

                        Text("Unlock VaxNear")
                            .font(.largeTitle.bold())

                        Text("Your complete vaccination companion")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "list.clipboard.fill", title: "Unlimited Records", subtitle: "Save as many vaccination records as you need")
                        FeatureRow(icon: "person.3.fill", title: "Family Profiles", subtitle: "Track vaccinations for your entire family")
                        FeatureRow(icon: "airplane", title: "Travel Vaccine Planning", subtitle: "Know what you need before you go")
                        FeatureRow(icon: "doc.richtext", title: "PDF Export", subtitle: "Share records with doctors and schools")
                    }
                    .padding(.horizontal, 4)

                    // Price
                    VStack(spacing: 8) {
                        if let product = storeManager.fullVersionProduct {
                            Text(product.displayPrice + " — One-Time Purchase")
                                .font(.title3.bold())
                        } else {
                            Text("$4.99 — One-Time Purchase")
                                .font(.title3.bold())
                        }
                        Text("No Subscription")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)

                    // Competitor note
                    Text("Other apps charge $0.99/mo or $4.99/wk.\nVaxNear is yours forever.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Buttons
                    VStack(spacing: 12) {
                        Button {
                            Task {
                                let success = await storeManager.purchase()
                                if success {
                                    onPurchaseComplete?()
                                    dismiss()
                                }
                            }
                        } label: {
                            if storeManager.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            } else {
                                Text("Purchase")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(storeManager.isLoading)

                        Button {
                            Task {
                                restoreSuccess = await storeManager.restorePurchases()
                                if restoreSuccess {
                                    onPurchaseComplete?()
                                    dismiss()
                                } else {
                                    showRestoreAlert = true
                                }
                            }
                        } label: {
                            Text("Restore Purchases")
                                .font(.subheadline)
                        }
                        .disabled(storeManager.isLoading)

                        Button("Not now") {
                            dismiss()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .task {
                await storeManager.loadProducts()
            }
            .alert("No Purchase Found", isPresented: $showRestoreAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("We couldn't find a previous purchase for this Apple ID.")
            }
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    PaywallView()
}
