import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreKitManager.shared
    @State private var showRestoreAlert = false
    @State private var restoreSuccess = false
    @State private var appeared = false

    var onPurchaseComplete: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            Image(systemName: "syringe.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.white)
                        }
                        .scaleEffect(appeared ? 1 : 0.8)
                        .opacity(appeared ? 1 : 0)

                        Text("Unlock VaxNear")
                            .font(.largeTitle.bold())
                            .opacity(appeared ? 1 : 0)

                        Text("Your complete vaccination companion")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .opacity(appeared ? 1 : 0)
                    }
                    .padding(.top, 20)
                    .animation(.easeOut(duration: 0.5), value: appeared)

                    // Features grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        FeatureCard(icon: "list.clipboard.fill", title: "Unlimited Records", color: .blue)
                        FeatureCard(icon: "person.3.fill", title: "Family Profiles", color: .purple)
                        FeatureCard(icon: "airplane", title: "Travel Planning", color: .orange)
                        FeatureCard(icon: "doc.richtext", title: "PDF Export", color: .green)
                    }
                    .padding(.horizontal, 4)

                    // Price card
                    VStack(spacing: 6) {
                        if let product = storeManager.fullVersionProduct {
                            Text(product.displayPrice)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        } else {
                            Text("$19.99")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        Text("One-Time Purchase — Yours Forever")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)

                    // Competitor comparison
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("Others")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("$19.99/wk")
                                .font(.caption.weight(.medium))
                                .strikethrough()
                                .foregroundStyle(.red.opacity(0.7))
                        }

                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        VStack(spacing: 4) {
                            Text("VaxNear")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                            Text("$19.99 once")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // CTA Buttons
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
                                    .padding(.vertical, 6)
                            } else {
                                Text("Purchase Now")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.blue)
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
                }
            }
            .task {
                await storeManager.loadProducts()
                withAnimation { appeared = true }
            }
            .alert("No Purchase Found", isPresented: $showRestoreAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("We couldn't find a previous purchase for this Apple ID.")
            }
        }
    }
}

// MARK: - Feature Card

private struct FeatureCard: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(title)
                .font(.caption.bold())
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    PaywallView()
}
