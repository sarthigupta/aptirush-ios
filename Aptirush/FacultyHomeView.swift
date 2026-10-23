import Observation
import SwiftUI

struct FacultyStudent: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let email: String
    let totalTests: Int
    let avgScore: String
    let isAssigned: Bool?
    let facultyId: String?
    let department: String?
    let batch: String?

    enum CodingKeys: String, CodingKey {
        case id
        case objectId = "_id"
        case studentId
        case userId
        case name
        case studentName
        case fullName
        case email
        case studentEmail
        case totalTests
        case testsCompleted
        case testCount
        case tests_completed
        case avgScore
        case averageScore
        case avg_score
        case accuracy
        case score
        case isAssigned
        case assigned
        case isMyStudent
        case myStudent
        case facultyId
        case assignedFacultyId
        case department
        case batch
    }

    init(
        id: String,
        name: String,
        email: String,
        totalTests: Int = 0,
        avgScore: String = "0%",
        isAssigned: Bool? = nil,
        facultyId: String? = nil,
        department: String? = nil,
        batch: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.totalTests = totalTests
        self.avgScore = avgScore
        self.isAssigned = isAssigned
        self.facultyId = facultyId
        self.department = department
        self.batch = batch
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // ID
        if let val = try? container.decodeIfPresent(String.self, forKey: .id), !val.isEmpty {
            self.id = val
        } else if let val = try? container.decodeIfPresent(String.self, forKey: .objectId), !val.isEmpty {
            self.id = val
        } else if let val = try? container.decodeIfPresent(String.self, forKey: .studentId), !val.isEmpty {
            self.id = val
        } else if let val = try? container.decodeIfPresent(String.self, forKey: .userId), !val.isEmpty {
            self.id = val
        } else {
            self.id = UUID().uuidString
        }

        // Name
        if let val = try? container.decodeIfPresent(String.self, forKey: .name), !val.isEmpty {
            self.name = val
        } else if let val = try? container.decodeIfPresent(String.self, forKey: .studentName), !val.isEmpty {
            self.name = val
        } else if let val = try? container.decodeIfPresent(String.self, forKey: .fullName), !val.isEmpty {
            self.name = val
        } else {
            self.name = "Unknown Student"
        }

        // Email
        if let val = try? container.decodeIfPresent(String.self, forKey: .email) {
            self.email = val
        } else if let val = try? container.decodeIfPresent(String.self, forKey: .studentEmail) {
            self.email = val
        } else {
            self.email = ""
        }

        // Total Tests
        if let val = try? container.decodeIfPresent(Int.self, forKey: .totalTests) {
            self.totalTests = val
        } else if let val = try? container.decodeIfPresent(Int.self, forKey: .testsCompleted) {
            self.totalTests = val
        } else if let val = try? container.decodeIfPresent(Int.self, forKey: .testCount) {
            self.totalTests = val
        } else if let val = try? container.decodeIfPresent(Int.self, forKey: .tests_completed) {
            self.totalTests = val
        } else if let str = try? container.decodeIfPresent(String.self, forKey: .totalTests), let val = Int(str) {
            self.totalTests = val
        } else if let str = try? container.decodeIfPresent(String.self, forKey: .testsCompleted), let val = Int(str) {
            self.totalTests = val
        } else {
            self.totalTests = 0
        }

        // Avg Score
        if let val = try? container.decodeIfPresent(String.self, forKey: .avgScore) {
            self.avgScore = val.contains("%") ? val : "\(val)%"
        } else if let val = try? container.decodeIfPresent(String.self, forKey: .averageScore) {
            self.avgScore = val.contains("%") ? val : "\(val)%"
        } else if let val = try? container.decodeIfPresent(String.self, forKey: .avg_score) {
            self.avgScore = val.contains("%") ? val : "\(val)%"
        } else if let val = try? container.decodeIfPresent(String.self, forKey: .accuracy) {
            self.avgScore = val.contains("%") ? val : "\(val)%"
        } else if let val = try? container.decodeIfPresent(String.self, forKey: .score) {
            self.avgScore = val.contains("%") ? val : "\(val)%"
        } else if let dbl = try? container.decodeIfPresent(Double.self, forKey: .avgScore) {
            self.avgScore = String(format: "%.0f%%", dbl)
        } else if let dbl = try? container.decodeIfPresent(Double.self, forKey: .averageScore) {
            self.avgScore = String(format: "%.0f%%", dbl)
        } else if let intVal = try? container.decodeIfPresent(Int.self, forKey: .avgScore) {
            self.avgScore = "\(intVal)%"
        } else {
            self.avgScore = "0%"
        }

        // Assigned flag
        if let val = try? container.decodeIfPresent(Bool.self, forKey: .isAssigned) {
            self.isAssigned = val
        } else if let val = try? container.decodeIfPresent(Bool.self, forKey: .assigned) {
            self.isAssigned = val
        } else if let val = try? container.decodeIfPresent(Bool.self, forKey: .isMyStudent) {
            self.isAssigned = val
        } else if let val = try? container.decodeIfPresent(Bool.self, forKey: .myStudent) {
            self.isAssigned = val
        } else if let str = try? container.decodeIfPresent(String.self, forKey: .isAssigned) {
            self.isAssigned = (str.lowercased() == "true")
        } else {
            self.isAssigned = nil
        }

        self.facultyId = (try? container.decodeIfPresent(String.self, forKey: .facultyId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .assignedFacultyId))
        self.department = try? container.decodeIfPresent(String.self, forKey: .department)
        self.batch = try? container.decodeIfPresent(String.self, forKey: .batch)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
        try container.encode(totalTests, forKey: .totalTests)
        try container.encode(avgScore, forKey: .avgScore)
        try container.encodeIfPresent(isAssigned, forKey: .isAssigned)
        try container.encodeIfPresent(facultyId, forKey: .facultyId)
        try container.encodeIfPresent(department, forKey: .department)
        try container.encodeIfPresent(batch, forKey: .batch)
    }

    var initials: String {
        let parts = name.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")
        if parts.count >= 2, let first = parts.first?.first, let last = parts.last?.first {
            return "\(first)\(last)".uppercased()
        } else if let first = name.first {
            return String(first).uppercased()
        }
        return "S"
    }

    var numericScore: Double {
        let cleaned = avgScore.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned) ?? 0.0
    }

    var scoreColor: Color {
        if numericScore >= 75 { return .green }
        if numericScore >= 50 { return .orange }
        if numericScore > 0 { return .yellow }
        return .secondary
    }

    var performanceRating: String {
        if totalTests == 0 && numericScore == 0 {
            return "Not Started"
        } else if numericScore >= 75 {
            return "Proficient"
        } else if numericScore >= 50 {
            return "Average"
        } else {
            return "Needs Practice"
        }
    }
}

struct FacultyStudentsResponse: Decodable {
    let students: [FacultyStudent]

    enum CodingKeys: String, CodingKey {
        case students
        case data
        case users
    }

    init(from decoder: Decoder) throws {
        if let directList = try? decoder.singleValueContainer().decode([FacultyStudent].self) {
            self.students = directList
            return
        }

        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            if let list = try? container.decodeIfPresent([FacultyStudent].self, forKey: .students) {
                self.students = list
                return
            }
            if let list = try? container.decodeIfPresent([FacultyStudent].self, forKey: .data) {
                self.students = list
                return
            }
            if let list = try? container.decodeIfPresent([FacultyStudent].self, forKey: .users) {
                self.students = list
                return
            }
        }

        self.students = []
    }
}

@MainActor
@Observable
final class FacultyViewModel {
    enum StudentScope: String, CaseIterable, Identifiable {
        case all = "All Students"
        case my = "My Students"

        var id: String { rawValue }
    }

    var selectedScope: StudentScope = .all
    var searchText: String = ""
    var selectedStudent: FacultyStudent? = nil

    private(set) var allStudents: [FacultyStudent] = []
    private(set) var myStudents: [FacultyStudent] = []
    private(set) var isLoading: Bool = false
    var errorMessage: String? = nil

    var filteredStudents: [FacultyStudent] {
        let baseList = (selectedScope == .my) ? myStudents : allStudents
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return baseList
        }
        return baseList.filter { student in
            student.name.lowercased().contains(query) ||
            student.email.lowercased().contains(query) ||
            (student.department?.lowercased().contains(query) ?? false) ||
            (student.batch?.lowercased().contains(query) ?? false)
        }
    }

    var allCount: Int {
        allStudents.count
    }

    var myCount: Int {
        myStudents.count
    }

    var activeCount: Int {
        allStudents.filter { $0.totalTests > 0 }.count
    }

    func load(token: String?, facultyUserId: String?) async {
        let rawToken = token ?? KeychainStore.token()
        guard let activeToken = rawToken?.trimmingCharacters(in: .whitespacesAndNewlines), !activeToken.isEmpty else {
            errorMessage = "No active session. Please sign in again."
            return
        }

        isLoading = true
        errorMessage = nil

        async let assignedTask = try? APIClient.shared.facultyStudents(token: activeToken)
        async let allTask = try? APIClient.shared.allFacultyStudents(token: activeToken)
        async let leaderboardTask = try? APIClient.shared.studentLeaderboard(token: activeToken)

        let (assignedResult, allResult, leaderboard) = await (assignedTask, allTask, leaderboardTask)

        var assignedList = assignedResult ?? []
        var fullList = allResult ?? []

        // If allResult has students, check if some are explicitly assigned
        let explicitlyAssigned = fullList.filter { student in
            student.isAssigned == true || (student.facultyId != nil && student.facultyId == facultyUserId)
        }

        if !explicitlyAssigned.isEmpty {
            assignedList = explicitlyAssigned
        } else if assignedList.isEmpty && !fullList.isEmpty {
            // When no explicit assignment flag, students from /faculty/students are assigned
            assignedList = fullList
        } else if fullList.isEmpty && !assignedList.isEmpty {
            fullList = assignedList
        }

        // Augment cohort from leaderboard if available
        if let leaderboard {
            var existingIds = Set(fullList.map(\.id))
            var augmented = fullList
            for entry in leaderboard where !existingIds.contains(entry.id) {
                existingIds.insert(entry.id)
                let cohortStudent = FacultyStudent(
                    id: entry.id,
                    name: entry.name,
                    email: entry.affiliation ?? "",
                    totalTests: 0,
                    avgScore: entry.accuracy ?? "0%",
                    isAssigned: false
                )
                augmented.append(cohortStudent)
            }
            fullList = augmented
        }

        self.allStudents = fullList
        self.myStudents = assignedList

        if allStudents.isEmpty && myStudents.isEmpty && assignedResult == nil && allResult == nil {
            errorMessage = "Failed to load students. Pull down to refresh."
        }

        isLoading = false
    }
}

struct FacultyHomeView: View {
    let name: String
    let session: SessionStore

    @State private var model = FacultyViewModel()
    @State private var showsCreateTest = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Header Summary
                FacultyHeaderView(
                    name: name,
                    allCount: model.allCount,
                    myCount: model.myCount,
                    activeCount: model.activeCount,
                    onCreateTest: {
                        showsCreateTest = true
                    }
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Scope Picker: All Students vs My Students
                Picker("Student Scope", selection: $model.selectedScope) {
                    Text("All Students (\(model.allCount))").tag(FacultyViewModel.StudentScope.all)
                    Text("My Students (\(model.myCount))").tag(FacultyViewModel.StudentScope.my)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 12)

                Divider()

                // Content Area
                Group {
                    if model.isLoading && model.allStudents.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            ProgressView("Loading students…")
                                .tint(.orange)
                            Spacer()
                        }
                    } else if let errorMessage = model.errorMessage, model.allStudents.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Button("Try Again") {
                                Task {
                                    await model.load(token: session.token, facultyUserId: session.user?.id)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            Spacer()
                        }
                    } else if model.filteredStudents.isEmpty {
                        FacultyEmptyStudentsView(
                            scope: model.selectedScope,
                            isSearching: !model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    } else {
                        List {
                            ForEach(model.filteredStudents) { student in
                                Button {
                                    model.selectedStudent = student
                                } label: {
                                    FacultyStudentRow(
                                        student: student,
                                        isAssigned: isAssignedToFaculty(student)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("Faculty Portal")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $model.searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search by student name or email"
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showsCreateTest = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Create Test")
                                .font(.subheadline.bold())
                        }
                        .foregroundStyle(.orange)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section("Faculty Profile") {
                            Label(name, systemImage: "person.fill")
                            if let email = session.user?.email, !email.isEmpty {
                                Label(email, systemImage: "envelope")
                            }
                        }
                        Section {
                            Button(role: .destructive) {
                                session.signOut()
                            } label: {
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .sheet(item: $model.selectedStudent) { student in
                FacultyStudentDetailSheet(
                    student: student,
                    isAssigned: isAssignedToFaculty(student)
                )
            }
            .sheet(isPresented: $showsCreateTest) {
                FacultyCreateTestSheet(
                    facultyName: name,
                    facultyID: session.user?.id,
                    token: session.token
                )
            }
            .task {
                await model.load(token: session.token, facultyUserId: session.user?.id)
            }
            .refreshable {
                await model.load(token: session.token, facultyUserId: session.user?.id)
            }
        }
    }

    private func isAssignedToFaculty(_ student: FacultyStudent) -> Bool {
        if student.isAssigned == true { return true }
        if let fid = student.facultyId, let myId = session.user?.id, fid == myId { return true }
        return model.myStudents.contains(where: { $0.id == student.id })
    }
}

struct FacultyHeaderView: View {
    let name: String
    let allCount: Int
    let myCount: Int
    let activeCount: Int
    var onCreateTest: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Welcome, \(name)")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)

                        Text("FACULTY")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.orange.opacity(0.18), in: Capsule())
                            .foregroundStyle(.orange)
                    }

                    Text("View and track all student aptitude metrics.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    onCreateTest?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Test")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.orange, in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            // Stat Cards
            HStack(spacing: 12) {
                FacultyStatBadge(
                    title: "All Students",
                    value: "\(allCount)",
                    icon: "person.3.fill",
                    color: .blue
                )

                FacultyStatBadge(
                    title: "My Students",
                    value: "\(myCount)",
                    icon: "person.badge.shield.checkmark.fill",
                    color: .orange
                )

                FacultyStatBadge(
                    title: "Active",
                    value: "\(activeCount)",
                    icon: "bolt.fill",
                    color: .green
                )
            }
        }
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct FacultyStatBadge: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct FacultyStudentRow: View {
    let student: FacultyStudent
    let isAssigned: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Student Initials Avatar
            ZStack {
                Circle()
                    .fill(isAssigned ? Color.orange.opacity(0.18) : Color.blue.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(student.initials)
                    .font(.subheadline.bold())
                    .foregroundStyle(isAssigned ? Color.orange : Color.blue)
            }

            // Name and Email
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(student.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    if isAssigned {
                        Text("My Student")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }

                if !student.email.isEmpty {
                    Text(student.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Performance & Tests Count
            VStack(alignment: .trailing, spacing: 4) {
                Text(student.avgScore)
                    .font(.subheadline.bold())
                    .foregroundStyle(student.scoreColor)

                Text("\(student.totalTests) tests")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption2.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct FacultyStudentDetailSheet: View {
    let student: FacultyStudent
    let isAssigned: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(isAssigned ? Color.orange.opacity(0.2) : Color.blue.opacity(0.15))
                                .frame(width: 72, height: 72)
                            Text(student.initials)
                                .font(.title.bold())
                                .foregroundStyle(isAssigned ? Color.orange : Color.blue)
                        }

                        VStack(spacing: 4) {
                            Text(student.name)
                                .font(.title2.bold())
                            Text(student.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            if isAssigned {
                                Label("Assigned Student", systemImage: "person.badge.shield.checkmark.fill")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.orange.opacity(0.15), in: Capsule())
                                    .foregroundStyle(.orange)
                            } else {
                                Label("General Cohort", systemImage: "person.2.fill")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.blue.opacity(0.15), in: Capsule())
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .padding(.top, 12)

                    // Performance Stats Grid
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Academic Performance")
                            .font(.headline)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            FacultyDetailStatCard(
                                title: "Average Score",
                                value: student.avgScore,
                                subtitle: student.performanceRating,
                                icon: "chart.line.uptrend.xyaxis",
                                color: student.scoreColor
                            )

                            FacultyDetailStatCard(
                                title: "Tests Completed",
                                value: "\(student.totalTests)",
                                subtitle: student.totalTests > 0 ? "Active practice" : "No tests yet",
                                icon: "doc.text.badge.checkmark",
                                color: .orange
                            )
                        }
                    }

                    // Student Information
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Student Details")
                            .font(.headline)

                        VStack(spacing: 10) {
                            FacultyDetailRow(label: "Student ID", value: student.id)
                            if let department = student.department, !department.isEmpty {
                                Divider()
                                FacultyDetailRow(label: "Department", value: department)
                            }
                            if let batch = student.batch, !batch.isEmpty {
                                Divider()
                                FacultyDetailRow(label: "Batch", value: batch)
                            }
                            Divider()
                            FacultyDetailRow(
                                label: "Status",
                                value: student.totalTests > 0 ? "Active" : "Inactive"
                            )
                        }
                        .padding()
                        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Student Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FacultyDetailStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(color)
            }

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct FacultyDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }
}

struct FacultyEmptyStudentsView: View {
    let scope: FacultyViewModel.StudentScope
    let isSearching: Bool

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: isSearching ? "magnifyingglass" : (scope == .my ? "person.badge.shield.checkmark" : "person.3"))
                .font(.system(size: 48))
                .foregroundStyle(.orange.opacity(0.8))

            Text(isSearching ? "No Matching Students" : (scope == .my ? "No Assigned Students" : "No Students Available"))
                .font(.headline)
                .foregroundStyle(.primary)

            Text(
                isSearching
                    ? "Check your search terms and try again."
                    : (scope == .my
                        ? "You do not have any students assigned to you yet. Switch to 'All Students' to browse all cohort students."
                        : "There are no student accounts enrolled at this time.")
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
