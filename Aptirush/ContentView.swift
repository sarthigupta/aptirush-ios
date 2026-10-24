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
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    AuthenticationHeader()

                    VStack(spacing: 20) {
                        Picker("Account type", selection: $selectedRole) {
                            Text("Student").tag(UserRole.student)
                            Text("Faculty").tag(UserRole.faculty)
                            Text("Admin").tag(UserRole.admin)
                        }
                        .pickerStyle(.segmented)

                        VStack(spacing: 12) {
                            // Sleek Input Field 1: Email
                            HStack(spacing: 14) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AestheticTheme.accent)
                                    .frame(width: 24)

                                TextField("Email address", text: $email)
                                    .textContentType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()

                                if !email.isEmpty {
                                    Button {
                                        email = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                            )

                            // Sleek Input Field 2: Password
                            HStack(spacing: 14) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AestheticTheme.accent)
                                    .frame(width: 24)

                                SecureField("Password", text: $password)
                                    .textContentType(.password)

                                if !password.isEmpty {
                                    Button {
                                        password = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                        }

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
                            HStack(spacing: 8) {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Sign In")
                                        .font(.headline.weight(.semibold))
                                    Image(systemName: "arrow.right")
                                        .font(.subheadline.bold())
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AestheticTheme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(email.isEmpty || password.isEmpty || isSubmitting)
                        .opacity((email.isEmpty || password.isEmpty || isSubmitting) ? 0.6 : 1.0)
                    }
                    .padding(20)
                    .luxuryGlass(cornerRadius: 20)

                    if selectedRole == .student {
                        Button {
                            showsRegistration = true
                        } label: {
                            HStack(spacing: 6) {
                                Text("New to AptiRush?")
                                    .foregroundStyle(.secondary)
                                Text("Create an account")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(AestheticTheme.accent)
                            }
                            .font(.subheadline)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Color(.secondarySystemBackground), in: Capsule())
                            .overlay(
                                Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                        }
                    } else if selectedRole == .faculty {
                        Text("Faculty accounts are provisioned by your institution.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
        }
    }
}

struct AuthenticationHeader: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AestheticTheme.accent)
                    .frame(width: 76, height: 76)
                    .shadow(color: AestheticTheme.accent.opacity(0.3), radius: 10, x: 0, y: 5)

                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                Text("AptiRush")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Practice smarter. Progress faster.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
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
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Join AptiRush")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("Set up your account to start speed duels, practice tests, and track your aptitude journey.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)

                    VStack(spacing: 16) {
                        // Name input
                        HStack(spacing: 14) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AestheticTheme.accent)
                                .frame(width: 24)

                            TextField("Full Name", text: $name)
                                .textContentType(.name)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )

                        // Email input
                        HStack(spacing: 14) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AestheticTheme.accent)
                                .frame(width: 24)

                            TextField("Email address", text: $email)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )

                        // Password input
                        HStack(spacing: 14) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AestheticTheme.accent)
                                .frame(width: 24)

                            SecureField("Password (at least 6 characters)", text: $password)
                                .textContentType(.newPassword)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )

                        if let errorMessage = session.errorMessage {
                            ErrorMessageView(message: errorMessage)
                        }

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
                            HStack(spacing: 8) {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Create Account")
                                        .font(.headline.weight(.semibold))
                                    Image(systemName: "arrow.right")
                                        .font(.subheadline.bold())
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AestheticTheme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(name.count < 2 || email.isEmpty || password.count < 6 || isSubmitting)
                        .opacity((name.count < 2 || email.isEmpty || password.count < 6 || isSubmitting) ? 0.6 : 1.0)
                    }
                    .padding(20)
                    .luxuryGlass(cornerRadius: 20)
                }
                .padding(20)
            }
        }
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
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
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            StudentTestsView(token: session.token, user: session.user)
                .tabItem {
                    Label("Tests", systemImage: "list.clipboard.fill")
                }
                .tag(1)

            BattleLobbyView(token: session.token, user: session.user)
                .tabItem {
                    Label("1v1 Arena", systemImage: "flag.2.crossed.fill")
                }
                .tag(2)

            StudentLearningView(token: session.token)
                .tabItem {
                    Label("Learn", systemImage: "book.fill")
                }
                .tag(3)

            AccountView(name: name, role: .student, session: session)
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle.fill")
                }
                .tag(4)
        }
        .tint(.orange)
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
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        StudentWelcomeHeader(name: name, streak: model.streak)

                        StudentHeroArenaCard(onSelectArena: onSelectArena)

                        StudentStatsGrid(
                            modulesCount: model.modulesCount,
                            accuracy: model.accuracy,
                            streak: model.streak,
                            isLoading: model.isLoading
                        )

                        StudentQuickActionsSection(
                            token: token,
                            user: user,
                            analytics: model.analytics,
                            onSelectArena: onSelectArena,
                            onSelectTests: onSelectTests
                        )
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
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
    let streak: Int

    private var greetingTimeOfDay: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        default: return "Good evening,"
        }
    }

    private var initials: String {
        let parts = name.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")
        if parts.count >= 2, let f = parts.first?.first, let l = parts.last?.first {
            return "\(f)\(l)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(greetingTimeOfDay)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    if streak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption2.bold())
                                .foregroundStyle(AestheticTheme.accent)
                            Text("\(streak)d streak")
                                .font(.caption2.bold())
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AestheticTheme.accent.opacity(0.12), in: Capsule())
                    }
                }

                Text(name)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)

                Text("Sharpen your aptitude with targeted practice.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            ZStack {
                Circle()
                    .fill(AestheticTheme.accent)
                    .frame(width: 48, height: 48)

                Text(initials)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StudentHeroArenaCard: View {
    let onSelectArena: (() -> Void)?

    var body: some View {
        Button {
            onSelectArena?()
        } label: {
            ZStack(alignment: .bottomLeading) {
                // High-Contrast Solid Obsidian/Titanium Surface
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AestheticTheme.darkCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )

                // Monochromatic Watermark Emblem
                HStack {
                    Spacer()
                    Image(systemName: "flag.2.crossed.fill")
                        .font(.system(size: 130))
                        .foregroundStyle(Color.white.opacity(0.04))
                        .offset(x: 20, y: 15)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                // Card Content
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(AestheticTheme.success)
                                .frame(width: 8, height: 8)

                            Text("LIVE 1V1 ARENA")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.10), in: Capsule())

                        Spacer()

                        Text("SPEED ROUNDS")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.70))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("1v1 Battle Arena")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.white)

                        Text("Challenge contenders in real-time speed duels or train against AI.")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.72))
                            .lineLimit(2)
                    }

                    HStack {
                        HStack(spacing: 6) {
                            Text("Enter Arena")
                                .font(.subheadline.bold())
                            Image(systemName: "arrow.right")
                                .font(.footnote.bold())
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AestheticTheme.accent, in: Capsule())

                        Spacer()

                        Text("Matchmaking Ready")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.white.opacity(0.60))
                    }
                }
                .padding(20)
            }
            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct StudentStatsGrid: View {
    let modulesCount: Int?
    let accuracy: String
    let streak: Int
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 12) {
            StudentStatCard(
                title: "MODULES",
                value: modulesCount.map(String.init) ?? (isLoading ? "…" : "—"),
                subtitle: "Curriculum",
                icon: "folder.fill",
                tint: AestheticTheme.accent
            )

            StudentStatCard(
                title: "ACCURACY",
                value: isLoading && accuracy == "—" ? "…" : accuracy,
                subtitle: "Overall pace",
                icon: "scope",
                tint: AestheticTheme.info
            )

            StudentStatCard(
                title: "DAY STREAK",
                value: isLoading ? "…" : "\(streak)",
                subtitle: "Active days",
                icon: "flame.fill",
                tint: AestheticTheme.warning
            )
        }
    }
}

struct StudentStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.12))
                        .frame(width: 34, height: 34)

                    Image(systemName: icon)
                        .font(.footnote.bold())
                        .foregroundStyle(tint)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .luxuryGlass(cornerRadius: 16)
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
            VStack(alignment: .leading, spacing: 4) {
                Text("EXPEDITIONS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                Text("Continue Learning")
                    .font(.system(.title3, design: .rounded).weight(.bold))
            }
            .padding(.top, 4)

            // 1. Assigned Tests
            Button {
                onSelectTests?()
            } label: {
                LuxuryQuickActionTile(
                    title: "Assigned Tests",
                    subtitle: "Institutional timed test sessions",
                    icon: "list.clipboard.fill",
                    iconColor: AestheticTheme.info,
                    badgeText: pendingTestsBadgeText,
                    badgeColor: AestheticTheme.info
                )
            }
            .buttonStyle(.plain)

            // 2. Learning Modules
            NavigationLink {
                StudentModulesView(token: token)
            } label: {
                LuxuryQuickActionTile(
                    title: "Browse Modules",
                    subtitle: "Structured aptitude chapters & quizzes",
                    icon: "book.closed.fill",
                    iconColor: AestheticTheme.accent,
                    badgeText: "Explore",
                    badgeColor: AestheticTheme.accent
                )
            }
            .buttonStyle(.plain)

            // 3. Performance Review
            NavigationLink {
                PerformanceReviewView(
                    token: token,
                    userID: user?.id,
                    initialAnalytics: analytics
                )
            } label: {
                LuxuryQuickActionTile(
                    title: "Review Performance",
                    subtitle: "Accuracy, pace metrics & ELO rating",
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: Color.purple,
                    badgeText: analytics?.mistakeCount.map { "\($0) in Vault" },
                    badgeColor: Color.purple
                )
            }
            .buttonStyle(.plain)

            // 4. Cohort Leaderboard
            NavigationLink {
                StudentLeaderboardView(token: token, currentUserID: user?.id)
            } label: {
                LuxuryQuickActionTile(
                    title: "Cohort Leaderboard",
                    subtitle: "Compare standings with batchmates",
                    icon: "trophy.fill",
                    iconColor: AestheticTheme.warning,
                    badgeText: "Rankings",
                    badgeColor: AestheticTheme.warning
                )
            }
            .buttonStyle(.plain)

            // 5. Mistake Vault
            NavigationLink {
                MistakeVaultView(token: token)
            } label: {
                LuxuryQuickActionTile(
                    title: "Mistake Vault",
                    subtitle: "Targeted practice on previously missed problems",
                    icon: "archivebox.fill",
                    iconColor: AestheticTheme.danger,
                    badgeText: analytics?.mistakeCount.map { "\($0) Items" },
                    badgeColor: AestheticTheme.danger
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var pendingTestsBadgeText: String? {
        let pending = TestStore.shared.tests.filter { TestStore.shared.attempts[$0.id] == nil }.count
        if pending > 0 {
            return "\(pending) New"
        } else if !TestStore.shared.tests.isEmpty {
            return "\(TestStore.shared.tests.count) Active"
        }
        return nil
    }
}

struct LuxuryQuickActionTile: View {
    let title: String
    let subtitle: String
    let icon: String
    var iconColor: Color = AestheticTheme.accent
    var badgeText: String? = nil
    var badgeColor: Color = AestheticTheme.accent

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if let badgeText {
                    Text(badgeText)
                        .font(.caption2.bold())
                        .foregroundStyle(badgeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(badgeColor.opacity(0.12), in: Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
                    .background(Color(.tertiarySystemFill), in: Circle())
            }
        }
        .padding(14)
        .luxuryGlass(cornerRadius: 16)
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

    @State private var showingSignOutConfirmation = false

    private var initials: String {
        let parts = name.split(separator: " ")
        if let first = parts.first?.prefix(1) {
            if parts.count > 1, let second = parts.last?.prefix(1) {
                return "\(first)\(second)".uppercased()
            }
            return String(first).uppercased()
        }
        return "AR"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientGlowCanvas(
                    primaryColor: Color.orange.opacity(0.12),
                    secondaryColor: Color.blue.opacity(0.08)
                )

                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Hero Slab
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(AestheticTheme.accent)
                                    .frame(width: 84, height: 84)

                                Text(initials)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .padding(.top, 8)

                            VStack(spacing: 4) {
                                Text(name)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.primary)

                                if let email = session.user?.email, !email.isEmpty {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            HStack(spacing: 8) {
                                Label(role.title, systemImage: roleIcon)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(roleColor.opacity(0.14), in: Capsule())
                                    .foregroundStyle(roleColor)

                                Label("Verified", systemImage: "checkmark.seal.fill")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.14), in: Capsule())
                                    .foregroundStyle(.green)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 20)
                        .luxuryGlass(cornerRadius: 24)

                        // Info & Settings Card
                        VStack(spacing: 16) {
                            AccountDetailRow(
                                title: "Full Name",
                                value: name,
                                icon: "person.fill",
                                iconColor: .orange
                            )
                            Divider().opacity(0.4)
                            AccountDetailRow(
                                title: "Role",
                                value: role.title,
                                icon: "shield.checkered",
                                iconColor: .blue
                            )
                            Divider().opacity(0.4)
                            AccountDetailRow(
                                title: "Platform",
                                value: "AptiRush iOS 2.0",
                                icon: "iphone",
                                iconColor: .purple
                            )
                        }
                        .padding(20)
                        .luxuryGlass(cornerRadius: 24)

                        // Sign Out Button
                        Button(role: .destructive) {
                            showingSignOutConfirmation = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.headline)
                                Text("Sign Out")
                                    .font(.headline.weight(.semibold))
                            }
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.red.opacity(0.25), lineWidth: 1)
                            )
                        }
                        .confirmationDialog("Are you sure you want to sign out?", isPresented: $showingSignOutConfirmation, titleVisibility: .visible) {
                            Button("Sign Out", role: .destructive) {
                                session.signOut()
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var roleIcon: String {
        switch role {
        case .student: return "graduationcap.fill"
        case .faculty: return "person.badge.key.fill"
        case .admin: return "crown.fill"
        }
    }

    private var roleColor: Color {
        switch role {
        case .student: return .orange
        case .faculty: return .indigo
        case .admin: return .purple
        }
    }
}

struct AccountDetailRow: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
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
