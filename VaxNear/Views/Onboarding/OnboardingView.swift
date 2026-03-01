import SwiftUI
import SwiftData
import UserNotifications

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @StateObject private var locationManager = LocationManager()
    @State private var currentPage = 0
    @State private var userName = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()

    private let pageCount = 5
    private let accentTeal = Color(red: 0.0, green: 0.6, blue: 0.65)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [accentTeal.opacity(0.08), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    profilePage.tag(1)
                    locationPage.tag(2)
                    notificationPage.tag(3)
                    readyPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                pageIndicator
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? accentTeal : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentPage ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Page \(currentPage + 1) of \(pageCount)")
    }

    // MARK: - Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "syringe.fill")
                .font(.system(size: 72))
                .foregroundStyle(accentTeal)
                .accessibilityHidden(true)

            Text("Find vaccines.\nTrack records.\nStay protected.")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("VaxNear helps you find vaccination sites near you, keep digital records, manage your family's immunizations, and plan travel vaccines — all in one app.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                withAnimation { currentPage = 1 }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(accentTeal)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Profile

    private var profilePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(accentTeal)
                .accessibilityHidden(true)

            Text("Create Your Profile")
                .font(.title2.bold())

            VStack(spacing: 16) {
                TextField("Your Name", text: $userName)
                    .textContentType(.name)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 32)

            Text("You can add family members later")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                createProfile()
                withAnimation { currentPage = 2 }
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(userName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : accentTeal)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(userName.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Location

    private var locationPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "map.fill")
                .font(.system(size: 64))
                .foregroundStyle(accentTeal)
                .accessibilityHidden(true)

            Text("Find vaccines near you")
                .font(.title2.bold())

            Text("VaxNear uses your location to find nearby vaccination sites, pharmacies, and clinics.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    locationManager.requestPermission()
                    withAnimation { currentPage = 3 }
                } label: {
                    Text("Enable Location")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(accentTeal)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    withAnimation { currentPage = 3 }
                } label: {
                    Text("Maybe Later")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Notifications

    private var notificationPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 64))
                .foregroundStyle(accentTeal)
                .accessibilityHidden(true)

            Text("Never miss a booster")
                .font(.title2.bold())

            Text("Get reminders for booster shots, seasonal vaccines, and upcoming appointments.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task {
                        let center = UNUserNotificationCenter.current()
                        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
                        await MainActor.run {
                            withAnimation { currentPage = 4 }
                        }
                    }
                } label: {
                    Text("Enable Notifications")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(accentTeal)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    withAnimation { currentPage = 4 }
                } label: {
                    Text("Maybe Later")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Ready

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(accentTeal)
                .accessibilityHidden(true)

            Text("You're all set!")
                .font(.title.bold())

            Text("Start by finding vaccines near you or adding your existing records.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    hasCompletedOnboarding = true
                } label: {
                    Text("Find Vaccines")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(accentTeal)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    hasCompletedOnboarding = true
                } label: {
                    Text("Add Records")
                        .font(.subheadline)
                        .foregroundStyle(accentTeal)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Helpers

    private func createProfile() {
        let trimmedName = userName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let profile = FamilyProfile(
            name: trimmedName,
            relationship: .selfUser,
            dateOfBirth: dateOfBirth
        )
        modelContext.insert(profile)
        try? modelContext.save()
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [FamilyProfile.self, AppSettings.self], inMemory: true)
}
