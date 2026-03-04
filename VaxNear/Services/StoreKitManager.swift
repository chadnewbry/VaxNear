import StoreKit
import SwiftData

@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    nonisolated static let fullVersionProductID = "com.chadnewbry.vaxnear.fullversion"

    @Published private(set) var fullVersionProduct: Product?
    @Published private(set) var isPurchased = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        guard fullVersionProduct == nil else { return }
        do {
            let products = try await Product.products(for: [Self.fullVersionProductID])
            fullVersionProduct = products.first
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase

    func purchase() async -> Bool {
        guard let product = fullVersionProduct else {
            errorMessage = "Product not available"
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                isPurchased = true
                return true
            case .userCancelled:
                return false
            case .pending:
                errorMessage = "Purchase is pending approval"
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
        } catch {
            errorMessage = "Could not connect to the App Store"
            return false
        }

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == Self.fullVersionProductID {
                isPurchased = true
                return true
            }
        }
        return false
    }

    // MARK: - Check Status on Launch

    func checkPurchaseStatus() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == Self.fullVersionProductID {
                isPurchased = true
                return
            }
        }
        isPurchased = false
    }

    // MARK: - Update AppSettings

    func syncSettingsIfNeeded(context: ModelContext) {
        let settings = AppSettings.shared(in: context)
        if isPurchased && !settings.hasPurchasedFullVersion {
            settings.hasPurchasedFullVersion = true
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? await self.checkVerified(result) {
                    if transaction.productID == Self.fullVersionProductID {
                        if transaction.revocationDate != nil {
                            await MainActor.run { self.isPurchased = false }
                        } else {
                            await MainActor.run { self.isPurchased = true }
                        }
                    }
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
