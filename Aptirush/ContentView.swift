import Observation
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var session = SessionStore()

    var body: some View {
        Group {
            if session.isRestoring {
                ProgressView("Restoring your session…")
            } else if session.isAuthenticated, let user = session.user {
                RoleHomeView(user: user, session: session)
            } else {
                AuthenticationView(session: session)
            }
        }
        .task {
            await session.restoreSession()
        }
    }
}

struct RoleHomeView: View {
    let user: UserProfile
    let session: SessionStore

    var body: some View {
        switch user.role {
        case .student:
            StudentHomeView(name: user.name, session: session)
        case .faculty:
            FacultyHomeView(name: user.name, session: session)
        case .admin:
            AdminHomeView(name: user.name, session: session)
        }
    }
}

struct AuthenticationView: View {
    let session: SessionStore
    @State private var showsRegistration = false

    var body: some View {
        NavigationStack {
            LoginFormView(session: session, showsRegistration: $showsRegistration)
                .navigationDestination(isPresented: $showsRegistration) {
                    StudentRegistrationView(session: session)
                }
        }
    }
}

struct LoginFormView: View {
    let session: SessionStore
    @Binding var showsRegistration: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var selectedRole: UserRole = .student
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 28) {
            AuthenticationHeader()

            VStack(spacing: 16) {
                Picker("Account type", selection: $selectedRole) {
                    Text("Student").tag(UserRole.student)
                    Text("Faculty").tag(UserRole.faculty)
                    Text("Admin").tag(UserRole.admin)
                }
                .pickerStyle(.segmented)

                TextField("Email address", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))

                if let errorMessage = session.errorMessage {
                    ErrorMessageView(message: errorMessage)
                }

                Button {
                    Task {
                        isSubmitting = true
                        _ = await session.signIn(email: email, password: password, role: selectedRole)
                        isSubmitting = false
                    }
                } label: {
                    Group {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(email.isEmpty || password.isEmpty || isSubmitting)
            }

            if selectedRole == .student {
                Button("Create a student account") {
                    showsRegistration = true
                }
                .buttonStyle(.borderless)
            } else if selectedRole == .faculty {
                Text("Faculty accounts are provisioned by your institution.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(24)
    }
}

struct AuthenticationHeader: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("AptiRush")
                .font(.largeTitle.bold())

            Text("Practice smarter. Progress faster.")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
    }
}

struct StudentRegistrationView: View {
    let session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false

    var body: some View {
        Form {
            Section("Your details") {
                TextField("Name", text: $name)
                    .textContentType(.name)
                TextField("Email address", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                SecureField("Password (at least 6 characters)", text: $password)
                    .textContentType(.newPassword)
            }

            if let errorMessage = session.errorMessage {
                Section {
                    ErrorMessageView(message: errorMessage)
                }
            }

            Section {
                Button {
                    Task {
                        isSubmitting = true
                        let didRegister = await session.registerStudent(
                            name: name,
                            email: email,
                            password: password
                        )
                        isSubmitting = false

                        if didRegister {
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Create Account")
                        }
                        Spacer()
                    }
                }
                .disabled(name.count < 2 || email.isEmpty || password.count < 6 || isSubmitting)
            }
        }
        .navigationTitle("Create Account")
    }
}

struct StudentHomeView: View {
    let name: String
    let session: SessionStore

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            StudentDashboardView(
                name: name,
                token: session.token,
                user: session.user,
                onSelectArena: { selectedTab = 2 },
                onSelectTests: { selectedTab = 1 }
            )
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(0)

            StudentTestsView(token: session.token, user: session.user)
                .tabItem {
                    Label("Tests", systemImage: "doc.text.badge.checkmark")
                }
                .tag(1)

            BattleLobbyView(token: session.token, user: session.user)
                .tabItem {
                    Label("1v1 Arena", systemImage: "flag.2.crossed.fill")
                }
                .tag(2)

            StudentLearningView(token: session.token)
                .tabItem {
                    Label("Learn", systemImage: "book")
                }
                .tag(3)

            AccountView(name: name, role: .student, session: session)
                .tabItem {
                    Label("Account", systemImage: "person")
                }
                .tag(4)
        }
    }
}

@MainActor
@Observable
final class StudentDashboardViewModel {
    private(set) var modulesCount: Int? = nil
    private(set) var accuracy: String = "—"
    private(set) var streak: Int = 0
    private(set) var analytics: StudentAnalytics? = nil
    private(set) var isLoading: Bool = false
    var errorMessage: String? = nil

    func load(token: String?, userID: String?) async {
        let rawToken = token ?? KeychainStore.token()
        guard let activeToken = rawToken?.trimmingCharacters(in: .whitespacesAndNewlines), !activeToken.isEmpty else {
            return
        }

        isLoading = true
        errorMessage = nil

        async let modulesTask = try? APIClient.shared.studentModules(token: activeToken)
        async let analyticsTask = try? APIClient.shared.studentAnalytics(token: activeToken)
        async let leaderboardTask = try? APIClient.shared.studentLeaderboard(token: activeToken)

        let (modules, fetchedAnalytics, leaderboard) = await (modulesTask, analyticsTask, leaderboardTask)

        if let modules {
            self.modulesCount = modules.count
        }

        if let fetchedAnalytics {
            self.analytics = fetchedAnalytics
            self.streak = fetchedAnalytics.currentStreak ?? 0
        }

        if let leaderboard {
            if let userID, let me = leaderboard.first(where: { $0.id == userID }), let acc = me.accuracy {
                self.accuracy = acc
            } else if let firstWithAcc = leaderboard.first(where: { $0.accuracy != nil }), let acc = firstWithAcc.accuracy {
                if self.accuracy == "—" {
                    self.accuracy = acc
                }
            } else if self.accuracy == "—" {
                self.accuracy = "0.0%"
            }
        }

        isLoading = false
    }
}

struct StudentDashboardView: View {
    let name: String
    let token: String?
    let user: UserProfile?
    var onSelectArena: (() -> Void)? = nil
    var onSelectTests: (() -> Void)? = nil

    @State private var model = StudentDashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    StudentWelcomeHeader(name: name)

                    StudentStatsGrid(
                        modulesCount: model.modulesCount,
                        accuracy: model.accuracy,
                        streak: model.streak,
                        isLoading: model.isLoading
                    )

                    Button {
                        onSelectArena?()
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(.orange.opacity(0.18))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "flag.2.crossed.fill")
                                    .font(.title2.bold())
                                    .foregroundStyle(.orange)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text("1v1 Battle Arena")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("LIVE")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.red, in: Capsule())
                                        .foregroundStyle(.white)
                                }
                                Text("Challenge batchmates or AI in real-time speed duels")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)

                    StudentQuickActionsSection(
                        token: token,
                        user: user,
                        analytics: model.analytics,
                        onSelectArena: onSelectArena,
                        onSelectTests: onSelectTests
                    )
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .task {
                await model.load(token: token, userID: user?.id)
            }
            .refreshable {
                await model.load(token: token, userID: user?.id)
            }
        }
    }
}

struct StudentWelcomeHeader: View {
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Welcome back,")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(name)
                .font(.largeTitle.bold())
            Text("Ready to sharpen your aptitude today?")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct StudentStatsGrid: View {
    let modulesCount: Int?
    let accuracy: String
    let streak: Int
    let isLoading: Bool

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StudentStatCard(
                title: "Modules",
                value: modulesCount.map(String.init) ?? (isLoading ? "…" : "—"),
                icon: "folder.fill",
                color: .orange
            )

            StudentStatCard(
                title: "Accuracy",
                value: isLoading && accuracy == "—" ? "…" : accuracy,
                icon: "scope",
                color: .blue
            )

            StudentStatCard(
                title: "Day Streak",
                value: isLoading ? "…" : "\(streak)",
                icon: "flame.fill",
                color: .red
            )
        }
    }
}

struct StudentStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct StudentQuickActionsSection: View {
    let token: String?
    let user: UserProfile?
    let analytics: StudentAnalytics?
    var onSelectArena: (() -> Void)? = nil
    var onSelectTests: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Continue Learning")
                .font(.title3.bold())

            Button {
                onSelectTests?()
            } label: {
                HStack {
                    Label("Assigned Tests", systemImage: "doc.text.badge.checkmark")
                    Spacer()
                    let pending = TestStore.shared.tests.filter { TestStore.shared.attempts[$0.id] == nil }.count
                    if pending > 0 {
                        Text("\(pending) New")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.2), in: Capsule())
                            .foregroundStyle(.orange)
                    } else if !TestStore.shared.tests.isEmpty {
                        Text("\(TestStore.shared.tests.count) Available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Button {
                onSelectArena?()
            } label: {
                HStack {
                    Label("1v1 Arena & Private Chamber", systemImage: "flag.2.crossed.fill")
                    Spacer()
                    Text("Duel")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.2), in: Capsule())
                        .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            NavigationLink {
                StudentModulesView(token: token)
            } label: {
                Label("Browse modules", systemImage: "book.closed")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
            }

            NavigationLink {
                PerformanceReviewView(
                    token: token,
                    userID: user?.id,
                    initialAnalytics: analytics
                )
            } label: {
                HStack {
                    Label("Review performance", systemImage: "chart.line.uptrend.xyaxis")
                    Spacer()
                    if let count = analytics?.mistakeCount, count > 0 {
                        Text("\(count) in Vault")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.purple.opacity(0.18), in: Capsule())
                            .foregroundStyle(.purple)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
            }

            NavigationLink {
                StudentLeaderboardView(token: token, currentUserID: user?.id)
            } label: {
                HStack {
                    Label("Cohort Leaderboard", systemImage: "trophy.fill")
                    Spacer()
                    Text("Rankings")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.yellow.opacity(0.2), in: Capsule())
                        .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
            }

            NavigationLink {
                MistakeVaultView(token: token)
            } label: {
                HStack {
                    Label("Mistake Vault", systemImage: "archivebox.fill")
                    Spacer()
                    if let count = analytics?.mistakeCount, count > 0 {
                        Text("\(count)")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.2), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

struct PerformanceReviewView: View {
    let token: String?
    let userID: String?
    var initialAnalytics: StudentAnalytics? = nil

    @State private var analytics: StudentAnalytics? = nil
    @State private var accuracy: String = "—"
    @State private var winRate: String = "—"
    @State private var avgSpeed: String = "—"
    @State private var mistakeCount: Int = 0
    @State private var leaderboardEntries: [LeaderboardEntry] = []
    @State private var showLeaderboardSheet = false
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading && analytics == nil {
                    ProgressView("Analyzing performance…")
                        .padding()
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        PerformanceMetricCard(
                            title: "Rating (ELO)",
                            value: analytics?.elo.map(String.init) ?? "1000",
                            icon: "trophy.fill",
                            color: .yellow
                        )

                        PerformanceMetricCard(
                            title: "Win Rate",
                            value: winRate,
                            icon: "flame.fill",
                            color: .orange
                        )

                        PerformanceMetricCard(
                            title: "Accuracy",
                            value: accuracy,
                            icon: "target",
                            color: .blue
                        )

                        PerformanceMetricCard(
                            title: "Avg Speed",
                            value: avgSpeed,
                            icon: "bolt.fill",
                            color: .purple
                        )

                        PerformanceMetricCard(
                            title: "Active Streak",
                            value: "\(analytics?.currentStreak ?? 0) days",
                            icon: "calendar",
                            color: .red
                        )

                        PerformanceMetricCard(
                            title: "Tests Today",
                            value: "\(analytics?.testsCompletedToday ?? 0)",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                    }

                    if let weakness = analytics?.weakness, !weakness.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Focus Area")
                                    .font(.headline)
                            }
                            Text("Your detected area for improvement is **\(weakness)**. Practice corresponding modules to increase your score.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.orange.opacity(0.3), lineWidth: 1)
                        )
                    }

                    // MARK: - GitHub-Style Activity Heatmap
                    GitHubActivityHeatmapView(
                        dailyActivity: analytics?.dailyActivity ?? [:],
                        currentStreak: analytics?.currentStreak ?? 0,
                        longestStreak: analytics?.longestStreak ?? 0
                    )

                    // MARK: - Topic-Wise Accuracy Breakdown
                    TopicAccuracyBreakdownView(
                        items: TopicAccuracyItem.generateItems(
                            weakness: analytics?.weakness,
                            attempts: TestStore.shared.attempts,
                            tests: TestStore.shared.tests
                        )
                    )

                    // MARK: - Mastery Badges
                    MasteryBadgesView(
                        badges: MasteryBadge.generateBadges(
                            accuracyString: accuracy,
                            elo: analytics?.elo,
                            streak: analytics?.currentStreak ?? 0,
                            testsCompleted: TestStore.shared.attempts.count,
                            mistakeCount: mistakeCount
                        )
                    )

                    // MARK: - Cohort Leaderboard Preview
                    LeaderboardPreviewCard(
                        topEntries: leaderboardEntries,
                        currentUserID: userID,
                        onOpenFullLeaderboard: {
                            showLeaderboardSheet = true
                        }
                    )

                    NavigationLink {
                        StudentLeaderboardView(token: token, currentUserID: userID)
                    } label: {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                            Text("Open Full Cohort Podium & Standings")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.yellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                    }

                    // MARK: - Mistake Vault
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "archivebox.fill")
                                .font(.title2)
                                .foregroundStyle(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mistake Vault")
                                    .font(.headline)
                                Text("\(mistakeCount) \(mistakeCount == 1 ? "question" : "questions") saved for review")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            NavigationLink {
                                MistakeVaultView(token: token)
                            } label: {
                                Text("Open Vault")
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(.purple, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding()
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))

                    NavigationLink {
                        MistakeVaultView(token: token)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                            Text("Practice Mistakes Now")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Performance")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLeaderboardSheet) {
            StudentLeaderboardView(token: token, currentUserID: userID)
        }
        .task {
            if let initialAnalytics {
                self.analytics = initialAnalytics
                self.mistakeCount = initialAnalytics.mistakeCount ?? 0
            }
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    private func loadData() async {
        let rawToken = token ?? KeychainStore.token()
        guard let activeToken = rawToken?.trimmingCharacters(in: .whitespacesAndNewlines), !activeToken.isEmpty else {
            return
        }

        isLoading = true
        async let a = try? APIClient.shared.studentAnalytics(token: activeToken)
        async let l = try? APIClient.shared.studentLeaderboard(token: activeToken)
        async let v = try? APIClient.shared.mistakeVault(token: activeToken)

        let (fetchedAnalytics, leaderboard, vault) = await (a, l, v)

        if let fetchedAnalytics {
            self.analytics = fetchedAnalytics
        }

        if let vault {
            self.mistakeCount = vault.count
        } else if let count = fetchedAnalytics?.mistakeCount {
            self.mistakeCount = count
        }

        if let leaderboard {
            self.leaderboardEntries = leaderboard
            if let userID, let me = leaderboard.first(where: { $0.id == userID }) {
                self.accuracy = me.accuracy ?? "0.0%"
                self.winRate = me.winRate ?? "0.0%"
                self.avgSpeed = me.avgSpeed ?? "—"
            } else if let first = leaderboard.first(where: { $0.accuracy != nil }) {
                self.accuracy = first.accuracy ?? "0.0%"
            }
        }
        isLoading = false
    }
}

struct PerformanceMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
    }
}

@MainActor
@Observable
final class MistakeVaultViewModel {
    private(set) var items: [MistakeVaultItem] = []
    private(set) var isLoading: Bool = false
    var errorMessage: String? = nil

    func load(token: String?) async {
        let rawToken = token ?? KeychainStore.token()
        guard let activeToken = rawToken?.trimmingCharacters(in: .whitespacesAndNewlines), !activeToken.isEmpty else {
            errorMessage = "Your session has expired. Please sign in again."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            items = try await APIClient.shared.mistakeVault(token: activeToken)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct MistakeVaultView: View {
    let token: String?
    @State private var model = MistakeVaultViewModel()

    var body: some View {
        Group {
            if model.isLoading && model.items.isEmpty {
                ProgressView("Loading Mistake Vault…")
            } else if let error = model.errorMessage, model.items.isEmpty {
                ContentUnavailableView {
                    Label("Unable to Load Vault", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") {
                        Task { await model.load(token: token) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if model.items.isEmpty {
                ContentUnavailableView(
                    "Mistake Vault is Empty",
                    systemImage: "checkmark.shield.fill",
                    description: Text("Any questions you answer incorrectly on module quizzes will appear here for practice and review.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(model.items.count) Questions to Master")
                                    .font(.headline)
                                Text("Review your incorrect choices and correct answers below.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "archivebox.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.purple)
                        }
                        .padding()
                        .background(.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

                        ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                            MistakeCardView(item: item, index: index + 1)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Mistake Vault")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.load(token: token)
        }
        .refreshable {
            await model.load(token: token)
        }
    }
}

struct MistakeCardView: View {
    let item: MistakeVaultItem
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Mistake #\(index)")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)

                if let type = item.type {
                    Text(type)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.fill.secondary, in: Capsule())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let dateStr = item.date, let formatted = formatDate(dateStr) {
                    Text(formatted)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(item.questionText)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            if !item.options.isEmpty {
                VStack(spacing: 8) {
                    ForEach(item.options) { opt in
                        let isUserAnswer = isMatch(opt, target: item.userAnswer)
                        let isCorrectAnswer = isMatch(opt, target: item.correctAnswer)

                        HStack(spacing: 12) {
                            if isCorrectAnswer {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else if isUserAnswer {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }

                            if !opt.id.isEmpty && opt.id.count <= 2 {
                                Text(opt.id + ".")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(isCorrectAnswer ? .green : (isUserAnswer ? .red : .primary))
                            }

                            Text(opt.text)
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Spacer(minLength: 0)

                            if isCorrectAnswer {
                                Text("Correct Answer")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.green.opacity(0.18), in: Capsule())
                                    .foregroundStyle(.green)
                            } else if isUserAnswer {
                                Text("Your Answer")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.red.opacity(0.18), in: Capsule())
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isCorrectAnswer ? Color.green.opacity(0.1) : (isUserAnswer ? Color.red.opacity(0.1) : Color(.secondarySystemBackground)))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isCorrectAnswer ? Color.green.opacity(0.5) : (isUserAnswer ? Color.red.opacity(0.5) : Color.clear), lineWidth: 1.2)
                        )
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let user = item.userAnswer {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("Your Answer:")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                            Text(user)
                                .font(.subheadline.bold())
                                .foregroundStyle(.red)
                        }
                    }

                    if let correct = item.correctAnswer {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Correct Answer:")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                            Text(correct)
                                .font(.subheadline.bold())
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding()
                .background(.fill.secondary, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func isMatch(_ opt: QuizOption, target: String?) -> Bool {
        guard let target = target?.trimmingCharacters(in: .whitespacesAndNewlines), !target.isEmpty else {
            return false
        }
        return opt.id.caseInsensitiveCompare(target) == .orderedSame || opt.text.caseInsensitiveCompare(target) == .orderedSame
    }

    private func formatDate(_ dateStr: String) -> String? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: dateStr) {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            return df.string(from: d)
        }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: dateStr) {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            return df.string(from: d)
        }
        return nil
    }
}

struct StudentLearningView: View {
    let token: String?

    var body: some View {
        NavigationStack {
            StudentModulesView(token: token)
        }
    }
}





struct AccountView: View {
    let name: String
    let role: UserRole
    let session: SessionStore

    var body: some View {
        NavigationStack {
            List {
                Section("Signed In As") {
                    LabeledContent("Name", value: name)
                    LabeledContent("Role", value: role.title)
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        session.signOut()
                    }
                }
            }
            .navigationTitle("Account")
        }
    }
}

struct BackendFeaturePlaceholderView: View {
    let title: String
    let detail: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: "arrow.triangle.2.circlepath",
            description: Text(detail)
        )
        .padding()
    }
}

struct ErrorMessageView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ContentView()
}
