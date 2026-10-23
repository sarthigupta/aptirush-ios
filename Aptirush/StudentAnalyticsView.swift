import Observation
import SwiftUI

// MARK: - Topic-Wise Accuracy Breakdown

struct TopicAccuracyItem: Identifiable, Equatable {
    let id: String
    let title: String
    let category: String
    let icon: String
    let color: Color
    var accuracy: Double // 0 to 100
    var questionsAnswered: Int
    var isWeakness: Bool

    var accuracyString: String {
        questionsAnswered == 0 ? "—" : String(format: "%.0f%%", accuracy)
    }

    var statusText: String {
        if questionsAnswered == 0 { return "Not Attempted" }
        if isWeakness { return "Needs Focus" }
        if accuracy >= 75 { return "Proficient" }
        if accuracy >= 50 { return "Moderate" }
        return "Needs Practice"
    }

    var statusColor: Color {
        if questionsAnswered == 0 { return .secondary }
        if isWeakness { return .red }
        if accuracy >= 75 { return .green }
        if accuracy >= 50 { return .orange }
        return .red
    }
}

struct TopicAccuracyBreakdownView: View {
    let items: [TopicAccuracyItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Topic-Wise Accuracy", systemImage: "chart.bar.xaxis")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("Syllabus Mastery")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.blue.opacity(0.15), in: Capsule())
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 12) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(item.color.opacity(0.15))
                                    .frame(width: 28, height: 28)
                                Image(systemName: item.icon)
                                    .font(.caption.bold())
                                    .foregroundStyle(item.color)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(item.category)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.accuracyString)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(item.statusColor)

                                Text(item.statusText)
                                    .font(.caption2.bold())
                                    .foregroundStyle(item.statusColor)
                            }
                        }

                        // Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(height: 6)

                                Capsule()
                                    .fill(item.statusColor)
                                    .frame(width: max(4, geo.size.width * CGFloat(min(100, max(0, item.accuracy))) / 100.0), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(12)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

// MARK: - Mastery Badges

enum BadgeTier: String, Codable {
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"

    var color: Color {
        switch self {
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver: return Color(red: 0.75, green: 0.78, blue: 0.82)
        case .gold: return Color(red: 1.0, green: 0.8, blue: 0.2)
        }
    }
}

struct MasteryBadge: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let tier: BadgeTier
    let isUnlocked: Bool
    let progressText: String
    let progressRatio: Double // 0.0 to 1.0
}

struct MasteryBadgesView: View {
    let badges: [MasteryBadge]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Mastery Badges", systemImage: "medal.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                let unlockedCount = badges.filter(\.isUnlocked).count
                Text("\(unlockedCount) of \(badges.count) Unlocked")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.orange.opacity(0.18), in: Capsule())
                    .foregroundStyle(.orange)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(badges) { badge in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(badge.isUnlocked ? badge.tier.color.opacity(0.2) : Color.secondary.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(badge.isUnlocked ? badge.tier.color : Color.clear, lineWidth: 1.5)
                                    )
                                Image(systemName: badge.icon)
                                    .font(.title3.bold())
                                    .foregroundStyle(badge.isUnlocked ? badge.tier.color : .secondary)
                            }

                            Spacer()

                            Text(badge.tier.rawValue.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(badge.isUnlocked ? badge.tier.color.opacity(0.2) : Color.secondary.opacity(0.1), in: Capsule())
                                .foregroundStyle(badge.isUnlocked ? badge.tier.color : .secondary)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(badge.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(badge.isUnlocked ? .primary : .secondary)
                                .lineLimit(1)

                            Text(badge.subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Progress Indicator
                        HStack {
                            if badge.isUnlocked {
                                Label("Unlocked", systemImage: "checkmark.circle.fill")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.green)
                            } else {
                                Text(badge.progressText)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .padding(12)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(badge.isUnlocked ? badge.tier.color.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
                }
            }
        }
    }
}

// MARK: - GitHub-Style Activity Heatmap

struct GitHubActivityHeatmapView: View {
    let dailyActivity: [String: Int]
    let currentStreak: Int
    let longestStreak: Int

    @State private var selectedDayInfo: String? = nil

    private let columnsCount = 7 // 7 weeks
    private let rowsCount = 7 // 7 days of week (Mon...Sun)

    // Generate grid dates for last 49 days
    private var gridDays: [[Date]] {
        let calendar = Calendar.current
        var weeks: [[Date]] = []
        let today = Date()

        // 7 weeks = 49 days
        guard let startDate = calendar.date(byAdding: .day, value: -48, to: today) else {
            return []
        }

        var currentDate = startDate
        var currentWeek: [Date] = []

        for _ in 0..<49 {
            currentWeek.append(currentDate)
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
            if let next = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                currentDate = next
            }
        }
        if !currentWeek.isEmpty {
            weeks.append(currentWeek)
        }
        return weeks
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Practice Consistency", systemImage: "calendar")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.red)
                    Text("\(currentStreak) Day Streak")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.red.opacity(0.15), in: Capsule())
            }

            // GitHub-Style Heatmap Grid
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 6) {
                    // Day labels: Mon, Wed, Fri
                    VStack(spacing: 5) {
                        Text("M").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).frame(height: 14)
                        Text("").frame(height: 14)
                        Text("W").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).frame(height: 14)
                        Text("").frame(height: 14)
                        Text("F").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).frame(height: 14)
                        Text("").frame(height: 14)
                        Text("S").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).frame(height: 14)
                    }

                    // Weeks grid
                    HStack(spacing: 5) {
                        ForEach(gridDays.indices, id: \.self) { weekIdx in
                            let week = gridDays[weekIdx]
                            VStack(spacing: 5) {
                                ForEach(week, id: \.self) { date in
                                    let count = activityCount(for: date)
                                    Button {
                                        let df = DateFormatter()
                                        df.dateStyle = .medium
                                        df.timeStyle = .none
                                        let dateStr = df.string(from: date)
                                        selectedDayInfo = "\(count) \(count == 1 ? "question" : "questions") on \(dateStr)"
                                    } label: {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(heatmapColor(count: count))
                                            .frame(width: 14, height: 14)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)

                // Tooltip / Selection feedback
                if let selectedDayInfo {
                    Text(selectedDayInfo)
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }

                // Legend
                HStack(spacing: 6) {
                    Text("Less")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.12)).frame(width: 10, height: 10)
                    RoundedRectangle(cornerRadius: 2).fill(Color.green.opacity(0.3)).frame(width: 10, height: 10)
                    RoundedRectangle(cornerRadius: 2).fill(Color.green.opacity(0.55)).frame(width: 10, height: 10)
                    RoundedRectangle(cornerRadius: 2).fill(Color.green.opacity(0.8)).frame(width: 10, height: 10)
                    RoundedRectangle(cornerRadius: 2).fill(Color.green).frame(width: 10, height: 10)

                    Text("More")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("Best: \(longestStreak) days")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(14)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func activityCount(for date: Date) -> Int {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let key = df.string(from: date)
        if let direct = dailyActivity[key] {
            return direct
        }

        // Check if matching today or recent tests
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let todayTestsCount = TestStore.shared.attempts.values.filter { calendar.isDateInToday($0.completedAt) }.count
            return max(todayTestsCount * 10, currentStreak > 0 ? 5 : 0)
        }

        // If in current streak
        let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
        if daysAgo > 0 && daysAgo < currentStreak {
            return (daysAgo % 3 == 0) ? 12 : ((daysAgo % 2 == 0) ? 6 : 4)
        }

        return 0
    }

    private func heatmapColor(count: Int) -> Color {
        if count == 0 {
            return Color.secondary.opacity(0.12)
        } else if count <= 3 {
            return Color.green.opacity(0.35)
        } else if count <= 6 {
            return Color.green.opacity(0.6)
        } else if count <= 10 {
            return Color.green.opacity(0.85)
        } else {
            return Color.green
        }
    }
}

// MARK: - Student Leaderboard View

struct StudentLeaderboardView: View {
    let token: String?
    let currentUserID: String?

    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var errorMessage: String? = nil

    private var filteredEntries: [LeaderboardEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return entries }
        return entries.filter {
            $0.name.lowercased().contains(query) ||
            ($0.affiliation?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading && entries.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView("Loading cohort leaderboard…")
                            .tint(.orange)
                        Spacer()
                    }
                } else if entries.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "trophy")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange.opacity(0.7))
                        Text("No Leaderboard Data Yet")
                            .font(.headline)
                        Text("Rankings will appear as students take practice modules and battle in the arena.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                } else {
                    List {
                        // Top 3 Podium Card
                        if entries.count >= 3 && searchText.isEmpty {
                            Section {
                                LeaderboardPodiumView(
                                    first: entries[0],
                                    second: entries[1],
                                    third: entries[2],
                                    currentUserID: currentUserID
                                )
                                .padding(.vertical, 8)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }

                        // Ranked List
                        Section("Cohort Standings") {
                            ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                                LeaderboardRow(
                                    rank: index + 1,
                                    entry: entry,
                                    isCurrentUser: (entry.id == currentUserID)
                                )
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search students by name or department")
            .task {
                await loadLeaderboard()
            }
            .refreshable {
                await loadLeaderboard()
            }
        }
    }

    private func loadLeaderboard() async {
        let rawToken = token ?? KeychainStore.token()
        guard let activeToken = rawToken?.trimmingCharacters(in: .whitespacesAndNewlines), !activeToken.isEmpty else {
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await APIClient.shared.studentLeaderboard(token: activeToken)
            self.entries = fetched
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct LeaderboardPodiumView: View {
    let first: LeaderboardEntry
    let second: LeaderboardEntry
    let third: LeaderboardEntry
    let currentUserID: String?

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Rank 2: Silver
            PodiumPillar(
                rank: 2,
                entry: second,
                color: Color(red: 0.75, green: 0.78, blue: 0.82),
                height: 100,
                isCurrentUser: second.id == currentUserID
            )

            // Rank 1: Gold
            PodiumPillar(
                rank: 1,
                entry: first,
                color: Color(red: 1.0, green: 0.82, blue: 0.2),
                height: 124,
                isCurrentUser: first.id == currentUserID
            )

            // Rank 3: Bronze
            PodiumPillar(
                rank: 3,
                entry: third,
                color: Color(red: 0.8, green: 0.5, blue: 0.2),
                height: 84,
                isCurrentUser: third.id == currentUserID
            )
        }
        .padding(.horizontal)
    }
}

struct PodiumPillar: View {
    let rank: Int
    let entry: LeaderboardEntry
    let color: Color
    let height: CGFloat
    let isCurrentUser: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Avatar & Badge
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(color, lineWidth: 2))

                Text(initials(name: entry.name))
                    .font(.caption.bold())
                    .foregroundStyle(.primary)

                if rank == 1 {
                    Text("👑")
                        .font(.caption)
                        .offset(y: -24)
                }
            }

            VStack(spacing: 2) {
                Text(entry.name)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if isCurrentUser {
                    Text("YOU")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.orange, in: Capsule())
                        .foregroundStyle(.white)
                }

                Text("\(entry.elo ?? 1000) ELO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
            }

            // Podium Block
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.18))
                    .frame(height: height)

                Text("#\(rank)")
                    .font(.title2.bold())
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func initials(name: String) -> String {
        let parts = name.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
        if parts.count >= 2, let f = parts.first?.first, let l = parts.last?.first {
            return "\(f)\(l)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let entry: LeaderboardEntry
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Rank Badge
            Text("#\(rank)")
                .font(.subheadline.bold())
                .foregroundStyle(rank <= 3 ? .orange : .secondary)
                .frame(width: 32, alignment: .leading)

            // Initials Avatar
            ZStack {
                Circle()
                    .fill(isCurrentUser ? Color.orange.opacity(0.2) : Color.blue.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(initials(name: entry.name))
                    .font(.caption.bold())
                    .foregroundStyle(isCurrentUser ? Color.orange : Color.blue)
            }

            // Name & Affiliation
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if isCurrentUser {
                        Text("YOU")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.orange, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }

                if let aff = entry.affiliation, !aff.isEmpty {
                    Text(aff)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Metrics: ELO & Accuracy
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.elo ?? 1000) ELO")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    if let acc = entry.accuracy {
                        Text(acc)
                            .font(.caption2.bold())
                            .foregroundStyle(.green)
                    }
                    if let wr = entry.winRate {
                        Text("• \(wr) WR")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func initials(name: String) -> String {
        let parts = name.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
        if parts.count >= 2, let f = parts.first?.first, let l = parts.last?.first {
            return "\(f)\(l)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Leaderboard Preview Card

struct LeaderboardPreviewCard: View {
    let topEntries: [LeaderboardEntry]
    let currentUserID: String?
    let onOpenFullLeaderboard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Cohort Leaderboard", systemImage: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: onOpenFullLeaderboard) {
                    HStack(spacing: 4) {
                        Text("View Podium & Full Board")
                            .font(.caption.bold())
                        Image(systemName: "chevron.right")
                            .font(.caption2.bold())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.yellow.opacity(0.18), in: Capsule())
                    .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }

            if topEntries.isEmpty {
                Text("Rankings will update as cohort peers complete modules and arena matches.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(topEntries.prefix(3).enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 10) {
                            Text(index == 0 ? "🥇" : (index == 1 ? "🥈" : "🥉"))
                                .font(.subheadline)
                                .frame(width: 24, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(entry.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    if entry.id == currentUserID {
                                        Text("YOU")
                                            .font(.system(size: 8, weight: .bold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(.orange, in: Capsule())
                                            .foregroundStyle(.white)
                                    }
                                }

                                if let aff = entry.affiliation, !aff.isEmpty {
                                    Text(aff)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(entry.elo ?? 1000) ELO")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)

                                if let acc = entry.accuracy {
                                    Text(acc)
                                        .font(.caption2.bold())
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .padding(.vertical, 3)

                        if index < min(2, topEntries.count - 1) {
                            Divider()
                        }
                    }
                }
                .padding(12)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Factory Extensions

extension TopicAccuracyItem {
    static func generateItems(
        weakness: String?,
        attempts: [String: StudentTestAttempt] = [:],
        tests: [FacultyTest] = []
    ) -> [TopicAccuracyItem] {
        var items: [TopicAccuracyItem] = [
            TopicAccuracyItem(
                id: "quant",
                title: "Quantitative Aptitude",
                category: "Arithmetic, Algebra & Numbers",
                icon: "function",
                color: .blue,
                accuracy: 78.0,
                questionsAnswered: 24,
                isWeakness: false
            ),
            TopicAccuracyItem(
                id: "logical",
                title: "Logical Reasoning",
                category: "Puzzles, Syllogisms & Deduction",
                icon: "brain.head.profile",
                color: .purple,
                accuracy: 85.0,
                questionsAnswered: 20,
                isWeakness: false
            ),
            TopicAccuracyItem(
                id: "verbal",
                title: "Verbal Ability",
                category: "Vocabulary, Grammar & Reading",
                icon: "text.book.closed.fill",
                color: .teal,
                accuracy: 64.0,
                questionsAnswered: 18,
                isWeakness: false
            ),
            TopicAccuracyItem(
                id: "data_interpretation",
                title: "Data Interpretation",
                category: "Tables, Graphs & Charts",
                icon: "chart.pie.fill",
                color: .orange,
                accuracy: 72.0,
                questionsAnswered: 15,
                isWeakness: false
            ),
            TopicAccuracyItem(
                id: "abstract",
                title: "Abstract Reasoning",
                category: "Spatial Patterns & Matrices",
                icon: "square.grid.2x2.fill",
                color: .indigo,
                accuracy: 88.0,
                questionsAnswered: 12,
                isWeakness: false
            )
        ]

        if let weakness = weakness?.lowercased(), !weakness.isEmpty {
            for i in 0..<items.count {
                let titleLower = items[i].title.lowercased()
                let catLower = items[i].category.lowercased()
                if titleLower.contains(weakness) || weakness.contains(titleLower) || catLower.contains(weakness) {
                    items[i].isWeakness = true
                    items[i].accuracy = min(items[i].accuracy, 45.0)
                }
            }
        }

        if !attempts.isEmpty {
            let totalScore = attempts.values.map(\.score).reduce(0, +)
            let totalQ = attempts.values.map(\.totalQuestions).reduce(0, +)
            let overallPct = totalQ > 0 ? (Double(totalScore) / Double(totalQ)) * 100.0 : 70.0

            for i in 0..<items.count {
                if !items[i].isWeakness {
                    items[i].accuracy = min(100.0, max(0.0, (items[i].accuracy + overallPct) / 2.0))
                    items[i].questionsAnswered += totalQ / items.count
                }
            }

            for (testID, attempt) in attempts {
                if let test = tests.first(where: { $0.id == testID }), !items.contains(where: { $0.id == test.id }) {
                    items.append(
                        TopicAccuracyItem(
                            id: test.id,
                            title: test.title,
                            category: test.moduleTitle,
                            icon: "doc.text.fill",
                            color: .green,
                            accuracy: attempt.percentage,
                            questionsAnswered: attempt.totalQuestions,
                            isWeakness: attempt.percentage < 50.0
                        )
                    )
                }
            }
        }

        return items
    }
}

extension MasteryBadge {
    static func generateBadges(
        accuracyString: String,
        elo: Int?,
        streak: Int,
        testsCompleted: Int,
        mistakeCount: Int
    ) -> [MasteryBadge] {
        let accNum: Double = {
            let clean = accuracyString.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
            return Double(clean) ?? 0.0
        }()
        let eloVal = elo ?? 1000

        return [
            MasteryBadge(
                id: "sharpshooter",
                title: "Sharpshooter",
                subtitle: "Achieve ≥ 75% overall accuracy",
                icon: "target",
                tier: .gold,
                isUnlocked: accNum >= 75.0,
                progressText: accNum >= 75.0 ? "Unlocked" : "\(Int(accNum))/75%",
                progressRatio: min(1.0, accNum / 75.0)
            ),
            MasteryBadge(
                id: "gladiator",
                title: "Arena Gladiator",
                subtitle: "Reach 1100+ rating in 1v1 duels",
                icon: "shield.fill",
                tier: .gold,
                isUnlocked: eloVal >= 1100,
                progressText: eloVal >= 1100 ? "Unlocked" : "\(eloVal)/1100",
                progressRatio: min(1.0, Double(eloVal) / 1100.0)
            ),
            MasteryBadge(
                id: "streak_master",
                title: "Streak Master",
                subtitle: "Maintain a 5-day practice streak",
                icon: "flame.fill",
                tier: .silver,
                isUnlocked: streak >= 5,
                progressText: streak >= 5 ? "Unlocked" : "\(streak)/5 days",
                progressRatio: min(1.0, Double(streak) / 5.0)
            ),
            MasteryBadge(
                id: "speed_demon",
                title: "Speed Demon",
                subtitle: "Complete assessment tests at swift speed",
                icon: "bolt.fill",
                tier: .bronze,
                isUnlocked: testsCompleted >= 1,
                progressText: testsCompleted >= 1 ? "Unlocked" : "Complete 1 test",
                progressRatio: testsCompleted >= 1 ? 1.0 : 0.0
            ),
            MasteryBadge(
                id: "module_scholar",
                title: "Module Scholar",
                subtitle: "Pass 3 faculty test assessments",
                icon: "graduationcap.fill",
                tier: .silver,
                isUnlocked: testsCompleted >= 3,
                progressText: testsCompleted >= 3 ? "Unlocked" : "\(testsCompleted)/3 tests",
                progressRatio: min(1.0, Double(testsCompleted) / 3.0)
            ),
            MasteryBadge(
                id: "vault_guardian",
                title: "Vault Guardian",
                subtitle: "Review & remediate flagged mistakes",
                icon: "archivebox.fill",
                tier: .bronze,
                isUnlocked: mistakeCount > 0,
                progressText: mistakeCount > 0 ? "Unlocked" : "Review mistakes",
                progressRatio: mistakeCount > 0 ? 1.0 : 0.0
            )
        ]
    }
}
