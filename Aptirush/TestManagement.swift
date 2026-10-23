import Observation
import SwiftUI
import Combine

// MARK: - Models

struct TestOption: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let text: String

    init(id: String, text: String) {
        self.id = id
        self.text = text
    }

    init(from option: QuizOption) {
        self.id = option.id
        self.text = option.text
    }
}

struct TestQuestion: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let text: String
    let options: [TestOption]
    let correctAnswer: String?
    let type: String?

    init(id: String, text: String, options: [TestOption], correctAnswer: String?, type: String?) {
        self.id = id
        self.text = text
        self.options = options
        self.correctAnswer = correctAnswer
        self.type = type
    }

    init(from quizQuestion: QuizQuestion) {
        self.id = quizQuestion.id
        self.text = quizQuestion.text
        self.options = quizQuestion.options.map { TestOption(from: $0) }
        self.correctAnswer = quizQuestion.correctAnswer
        self.type = quizQuestion.type
    }
}

struct FacultyTest: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let moduleID: String
    let moduleTitle: String
    let facultyName: String
    let facultyID: String?
    let durationMinutes: Int
    let questions: [TestQuestion]
    let createdAt: Date

    var questionCount: Int {
        questions.count
    }

    enum CodingKeys: String, CodingKey {
        case id
        case objectID = "_id"
        case title
        case name
        case moduleID
        case moduleId
        case module_id
        case moduleTitle
        case module_title
        case moduleName
        case facultyName
        case faculty_name
        case createdBy
        case facultyID
        case facultyId
        case durationMinutes
        case duration
        case duration_minutes
        case timeLimit
        case questions
        case createdAt
        case created_at
    }

    init(
        id: String,
        title: String,
        moduleID: String,
        moduleTitle: String,
        facultyName: String,
        facultyID: String?,
        durationMinutes: Int,
        questions: [TestQuestion],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.moduleID = moduleID
        self.moduleTitle = moduleTitle
        self.facultyName = facultyName
        self.facultyID = facultyID
        self.durationMinutes = durationMinutes
        self.questions = questions
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = (try? container.decodeIfPresent(String.self, forKey: .id))
            ?? (try? container.decodeIfPresent(String.self, forKey: .objectID))
            ?? UUID().uuidString

        self.title = (try? container.decodeIfPresent(String.self, forKey: .title))
            ?? (try? container.decodeIfPresent(String.self, forKey: .name))
            ?? "Assessment Test"

        self.moduleID = (try? container.decodeIfPresent(String.self, forKey: .moduleID))
            ?? (try? container.decodeIfPresent(String.self, forKey: .moduleId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .module_id))
            ?? ""

        self.moduleTitle = (try? container.decodeIfPresent(String.self, forKey: .moduleTitle))
            ?? (try? container.decodeIfPresent(String.self, forKey: .module_title))
            ?? (try? container.decodeIfPresent(String.self, forKey: .moduleName))
            ?? "Module"

        self.facultyName = (try? container.decodeIfPresent(String.self, forKey: .facultyName))
            ?? (try? container.decodeIfPresent(String.self, forKey: .faculty_name))
            ?? (try? container.decodeIfPresent(String.self, forKey: .createdBy))
            ?? "Faculty"

        self.facultyID = (try? container.decodeIfPresent(String.self, forKey: .facultyID))
            ?? (try? container.decodeIfPresent(String.self, forKey: .facultyId))

        if let mins = try? container.decodeIfPresent(Int.self, forKey: .durationMinutes) {
            self.durationMinutes = mins
        } else if let mins = try? container.decodeIfPresent(Int.self, forKey: .duration) {
            self.durationMinutes = mins
        } else if let mins = try? container.decodeIfPresent(Int.self, forKey: .duration_minutes) {
            self.durationMinutes = mins
        } else if let mins = try? container.decodeIfPresent(Int.self, forKey: .timeLimit) {
            self.durationMinutes = mins
        } else {
            self.durationMinutes = 15
        }

        self.questions = (try? container.decodeIfPresent([TestQuestion].self, forKey: .questions)) ?? []

        if let date = try? container.decodeIfPresent(Date.self, forKey: .createdAt) {
            self.createdAt = date
        } else if let dateStr = try? container.decodeIfPresent(String.self, forKey: .createdAt),
                  let date = ISO8601DateFormatter().date(from: dateStr) {
            self.createdAt = date
        } else if let dateStr = try? container.decodeIfPresent(String.self, forKey: .created_at),
                  let date = ISO8601DateFormatter().date(from: dateStr) {
            self.createdAt = date
        } else {
            self.createdAt = Date()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(moduleID, forKey: .moduleID)
        try container.encode(moduleTitle, forKey: .moduleTitle)
        try container.encode(facultyName, forKey: .facultyName)
        try container.encodeIfPresent(facultyID, forKey: .facultyID)
        try container.encode(durationMinutes, forKey: .durationMinutes)
        try container.encode(questions, forKey: .questions)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

struct StudentTestAttempt: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let testID: String
    let studentID: String
    let studentName: String
    let score: Int
    let totalQuestions: Int
    let percentage: Double
    let completedAt: Date

    var isPassed: Bool {
        percentage >= 50.0
    }
}

// MARK: - Test Store

@MainActor
@Observable
final class TestStore {
    static let shared = TestStore()

    private(set) var tests: [FacultyTest] = []
    private(set) var attempts: [String: StudentTestAttempt] = [:] // Keyed by testID
    private(set) var isLoading: Bool = false
    var errorMessage: String? = nil

    private let testsStorageKey = "aptirush.tests.v1"
    private let attemptsStorageKey = "aptirush.test_attempts.v1"

    init() {
        loadFromLocalStorage()
    }

    func loadFromLocalStorage() {
        if let data = UserDefaults.standard.data(forKey: testsStorageKey),
           let saved = try? JSONDecoder().decode([FacultyTest].self, from: data) {
            self.tests = saved
        }
        if let data = UserDefaults.standard.data(forKey: attemptsStorageKey),
           let saved = try? JSONDecoder().decode([String: StudentTestAttempt].self, from: data) {
            self.attempts = saved
        }
    }

    func saveToLocalStorage() {
        if let data = try? JSONEncoder().encode(tests) {
            UserDefaults.standard.set(data, forKey: testsStorageKey)
        }
        if let data = try? JSONEncoder().encode(attempts) {
            UserDefaults.standard.set(data, forKey: attemptsStorageKey)
        }
    }

    func refresh(token: String?) async {
        guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            loadFromLocalStorage()
            return
        }

        isLoading = true
        errorMessage = nil

        // Attempt remote load if available
        if let remoteTests = try? await APIClient.shared.fetchStudentTests(token: token), !remoteTests.isEmpty {
            var merged = remoteTests
            let remoteIDs = Set(remoteTests.map(\.id))
            for localTest in tests where !remoteIDs.contains(localTest.id) {
                merged.append(localTest)
            }
            self.tests = merged
            saveToLocalStorage()
        } else {
            loadFromLocalStorage()
        }

        isLoading = false
    }

    func addTest(_ test: FacultyTest, token: String?) async {
        tests.insert(test, at: 0)
        saveToLocalStorage()

        // Also push to backend if available
        if let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            _ = try? await APIClient.shared.createFacultyTest(
                title: test.title,
                moduleID: test.moduleID,
                durationMinutes: test.durationMinutes,
                questions: test.questions,
                token: token
            )
        }
    }

    func recordAttempt(
        testID: String,
        studentID: String,
        studentName: String,
        score: Int,
        totalQuestions: Int,
        token: String?
    ) {
        let percentage = totalQuestions > 0 ? (Double(score) / Double(totalQuestions) * 100.0) : 0.0
        let attempt = StudentTestAttempt(
            id: UUID().uuidString,
            testID: testID,
            studentID: studentID,
            studentName: studentName,
            score: score,
            totalQuestions: totalQuestions,
            percentage: percentage,
            completedAt: Date()
        )
        attempts[testID] = attempt
        saveToLocalStorage()

        // Attempt reporting to backend
        if let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            Task {
                let submission = AttemptSubmission(
                    moduleId: testID,
                    score: score,
                    total: totalQuestions,
                    customTestId: testID,
                    durationMs: 0,
                    mistakes: []
                )
                try? await APIClient.shared.submitAttempt(submission, token: token)
            }
        }
    }

    func attemptFor(testID: String) -> StudentTestAttempt? {
        attempts[testID]
    }
}

// MARK: - Faculty Create Test Sheet

struct FacultyCreateTestSheet: View {
    let facultyName: String
    let facultyID: String?
    let token: String?
    var onCreated: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var modules: [LearningModule] = []
    @State private var selectedModule: LearningModule? = nil
    @State private var title: String = ""
    @State private var durationMinutes: Int = 15
    @State private var questionCount: Int = 10
    @State private var availableQuestions: [QuizQuestion] = []
    @State private var isLoadingModules = false
    @State private var isLoadingQuestions = false
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var didCreate = false

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                // Step 1: Select Module
                Section("1. Select Module") {
                    if isLoadingModules {
                        HStack {
                            ProgressView()
                            Text("Loading syllabus modules…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if modules.isEmpty {
                        Text("No modules available.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Module", selection: $selectedModule) {
                            Text("Select a module").tag(Optional<LearningModule>.none)
                            ForEach(modules) { module in
                                Text(module.title).tag(Optional(module))
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedModule) { _, newModule in
                            if let newModule {
                                title = "\(newModule.title) Test"
                                Task {
                                    await loadQuestionsForModule(newModule)
                                }
                            }
                        }
                    }

                    if let selectedModule {
                        HStack {
                            Text("Chapter")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(selectedModule.chapterNumber ?? 1)")
                                .bold()
                        }
                    }
                }

                // Step 2: Configure Test Details
                if selectedModule != nil {
                    Section("2. Test Configuration") {
                        TextField("Test Title", text: $title)

                        Stepper(value: $durationMinutes, in: 5...120, step: 5) {
                            HStack {
                                Text("Duration")
                                Spacer()
                                Text("\(durationMinutes) minutes")
                                    .bold()
                                    .foregroundStyle(.orange)
                            }
                        }

                        if isLoadingQuestions {
                            HStack {
                                ProgressView()
                                Text("Loading module questions…")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else if !availableQuestions.isEmpty {
                            Stepper(
                                value: $questionCount,
                                in: 1...max(1, availableQuestions.count)
                            ) {
                                HStack {
                                    Text("Questions")
                                    Spacer()
                                    Text("\(questionCount) of \(availableQuestions.count)")
                                        .bold()
                                        .foregroundStyle(.orange)
                                }
                            }

                            HStack {
                                Text("Time per question")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                let timePerQ = Double(durationMinutes * 60) / Double(max(1, questionCount))
                                Text(String(format: "%.0fs", timePerQ))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("No questions found in this module yet.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Step 3: Publish Button
                    Section {
                        Button {
                            Task {
                                await createTest()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if isSubmitting {
                                    ProgressView()
                                } else {
                                    Label("Publish Test to Students", systemImage: "paperplane.fill")
                                        .bold()
                                }
                                Spacer()
                            }
                        }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || availableQuestions.isEmpty || isSubmitting)
                        .tint(.orange)
                    }
                }
            }
            .navigationTitle("Create Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadModules()
            }
            .alert("Test Created!", isPresented: $didCreate) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("The test has been published successfully and is now visible to all students in their Tests section.")
            }
        }
    }

    private func loadModules() async {
        guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            return
        }
        isLoadingModules = true
        errorMessage = nil
        do {
            self.modules = try await APIClient.shared.studentModules(token: token)
            if selectedModule == nil, let first = modules.first {
                selectedModule = first
                title = "\(first.title) Test"
                await loadQuestionsForModule(first)
            }
        } catch {
            errorMessage = "Failed to load modules: \(error.localizedDescription)"
        }
        isLoadingModules = false
    }

    private func loadQuestionsForModule(_ module: LearningModule) async {
        guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            return
        }
        isLoadingQuestions = true
        do {
            let quiz = try await APIClient.shared.moduleQuiz(id: module.id, token: token)
            self.availableQuestions = quiz.questions
            self.questionCount = min(10, max(1, quiz.questions.count))
        } catch {
            self.availableQuestions = []
        }
        isLoadingQuestions = false
    }

    private func createTest() async {
        guard let selectedModule else { return }
        isSubmitting = true
        errorMessage = nil

        let selectedQuestions = Array(availableQuestions.prefix(questionCount)).map { TestQuestion(from: $0) }
        let newTest = FacultyTest(
            id: UUID().uuidString,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            moduleID: selectedModule.id,
            moduleTitle: selectedModule.title,
            facultyName: facultyName,
            facultyID: facultyID,
            durationMinutes: durationMinutes,
            questions: selectedQuestions,
            createdAt: Date()
        )

        await TestStore.shared.addTest(newTest, token: token)
        isSubmitting = false
        didCreate = true
        onCreated?()
    }
}

// MARK: - Student Tests View

struct StudentTestsView: View {
    let token: String?
    let user: UserProfile?

    @State private var store = TestStore.shared
    @State private var filterIndex: Int = 0 // 0: All, 1: Pending, 2: Completed
    @State private var testToTake: FacultyTest? = nil

    private var filteredTests: [FacultyTest] {
        switch filterIndex {
        case 1:
            return store.tests.filter { store.attempts[$0.id] == nil }
        case 2:
            return store.tests.filter { store.attempts[$0.id] != nil }
        default:
            return store.tests
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Scope: All / Pending / Completed
                Picker("Status", selection: $filterIndex) {
                    Text("All (\(store.tests.count))").tag(0)
                    let pendingCount = store.tests.filter { store.attempts[$0.id] == nil }.count
                    Text("Pending (\(pendingCount))").tag(1)
                    let completedCount = store.tests.filter { store.attempts[$0.id] != nil }.count
                    Text("Completed (\(completedCount))").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                if store.isLoading && store.tests.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView("Loading tests…")
                            .tint(.orange)
                        Spacer()
                    }
                } else if filteredTests.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange.opacity(0.8))
                        Text(filterIndex == 2 ? "No Completed Tests" : (filterIndex == 1 ? "No Pending Tests" : "No Tests Available"))
                            .font(.headline)
                        Text(filterIndex == 2 ? "Take a test to see your results here." : "Tests created by your faculty will appear here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredTests) { test in
                            StudentTestCard(
                                test: test,
                                attempt: store.attempts[test.id],
                                onTakeTest: {
                                    testToTake = test
                                }
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Assigned Tests")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $testToTake) { test in
                StudentTakeTestView(
                    test: test,
                    studentID: user?.id ?? "",
                    studentName: user?.name ?? "Student",
                    token: token
                )
            }
            .task {
                await store.refresh(token: token)
            }
            .refreshable {
                await store.refresh(token: token)
            }
        }
    }
}

struct StudentTestCard: View {
    let test: FacultyTest
    let attempt: StudentTestAttempt?
    let onTakeTest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Title & Status
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(test.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Image(systemName: "book.closed.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text(test.moduleTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let attempt {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(attempt.score)/\(attempt.totalQuestions)")
                            .font(.subheadline.bold())
                            .foregroundStyle(attempt.isPassed ? .green : .orange)

                        Text(String(format: "%.0f%%", attempt.percentage))
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((attempt.isPassed ? Color.green : Color.orange).opacity(0.15), in: Capsule())
                            .foregroundStyle(attempt.isPassed ? .green : .orange)
                    }
                } else {
                    Text("Available")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.blue.opacity(0.15), in: Capsule())
                        .foregroundStyle(.blue)
                }
            }

            // Meta Info: Duration, Questions, Faculty
            HStack(spacing: 16) {
                Label("\(test.durationMinutes)m", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("\(test.questionCount) Questions", systemImage: "list.bullet")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("By \(test.facultyName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Action Button
            HStack {
                if let attempt {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Completed on \(formattedDate(attempt.completedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Retake") {
                        onTakeTest()
                    }
                    .font(.subheadline.bold())
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Spacer()
                    Button {
                        onTakeTest()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Start Test")
                            Image(systemName: "play.fill")
                                .font(.caption2)
                        }
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.orange, in: Capsule())
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
    }
}

// MARK: - Student Take Test View

struct StudentTakeTestView: View {
    let test: FacultyTest
    let studentID: String
    let studentName: String
    let token: String?

    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int = 0
    @State private var selectedAnswers: [String: String] = [:] // QuestionID : OptionID
    @State private var secondsRemaining: Int
    @State private var timer: Publishers.Autoconnect<Timer.TimerPublisher>? = nil
    @State private var showsSubmitAlert = false
    @State private var completedAttempt: StudentTestAttempt? = nil

    init(test: FacultyTest, studentID: String, studentName: String, token: String?) {
        self.test = test
        self.studentID = studentID
        self.studentName = studentName
        self.token = token
        _secondsRemaining = State(initialValue: test.durationMinutes * 60)
    }

    var body: some View {
        NavigationStack {
            if let attempt = completedAttempt {
                TestResultView(attempt: attempt, test: test) {
                    dismiss()
                }
            } else if test.questions.isEmpty {
                VStack(spacing: 16) {
                    Text("No questions in this test.")
                        .font(.headline)
                    Button("Close") {
                        dismiss()
                    }
                }
            } else {
                VStack(spacing: 0) {
                    // Top Progress & Timer Bar
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Question \(currentIndex + 1) of \(test.questions.count)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            ProgressView(value: Double(currentIndex + 1), total: Double(test.questions.count))
                                .tint(.orange)
                        }

                        Spacer(minLength: 24)

                        // Countdown Timer
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(secondsRemaining < 60 ? .red : .orange)
                            Text(timeFormatted(secondsRemaining))
                                .font(.subheadline.monospacedDigit().bold())
                                .foregroundStyle(secondsRemaining < 60 ? .red : .primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .padding()

                    Divider()

                    // Question & Options Content
                    let question = test.questions[currentIndex]

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(question.text)
                                .font(.title3.bold())
                                .foregroundStyle(.primary)

                            VStack(spacing: 12) {
                                ForEach(question.options) { option in
                                    TestOptionRow(
                                        option: option,
                                        isSelected: selectedAnswers[question.id] == option.id,
                                        onSelect: {
                                            selectedAnswers[question.id] = option.id
                                        }
                                    )
                                }
                            }
                        }
                        .padding()
                    }

                    Divider()

                    // Bottom Navigation Buttons
                    HStack {
                        Button {
                            if currentIndex > 0 {
                                currentIndex -= 1
                            }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Previous")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(currentIndex == 0)

                        Spacer()

                        if currentIndex == test.questions.count - 1 {
                            Button {
                                showsSubmitAlert = true
                            } label: {
                                Text("Submit Test")
                                    .bold()
                                    .padding(.horizontal, 16)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        } else {
                            Button {
                                if currentIndex < test.questions.count - 1 {
                                    currentIndex += 1
                                }
                            } label: {
                                HStack {
                                    Text("Next")
                                    Image(systemName: "chevron.right")
                                }
                                .padding(.horizontal, 16)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                    }
                    .padding()
                }
                .navigationTitle(test.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Quit") {
                            showsSubmitAlert = true
                        }
                    }
                }
                .onAppear {
                    startTimer()
                }
                .alert("Submit Test?", isPresented: $showsSubmitAlert) {
                    Button("Submit", role: .none) {
                        submitTest()
                    }
                    Button("Keep Working", role: .cancel) {}
                } message: {
                    let answered = selectedAnswers.count
                    Text("You have answered \(answered) of \(test.questions.count) questions. Once submitted, your score will be recorded.")
                }
            }
        }
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        _ = timer?.sink { _ in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                submitTest()
            }
        }
    }

    private func submitTest() {
        var score = 0
        for question in test.questions {
            if let selected = selectedAnswers[question.id],
               let correct = question.correctAnswer {
                let normSelected = selected.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let normCorrect = correct.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if normSelected == normCorrect {
                    score += 1
                } else if let matching = question.options.first(where: { $0.id.lowercased() == normSelected }),
                          matching.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normCorrect {
                    score += 1
                }
            }
        }

        TestStore.shared.recordAttempt(
            testID: test.id,
            studentID: studentID,
            studentName: studentName,
            score: score,
            totalQuestions: test.questions.count,
            token: token
        )

        completedAttempt = TestStore.shared.attemptFor(testID: test.id)
    }

    private func timeFormatted(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct TestOptionRow: View {
    let option: TestOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.orange : Color.secondary.opacity(0.4), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    if isSelected {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 16, height: 16)
                    }
                }

                Text(option.text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding()
            .background(isSelected ? Color.orange.opacity(0.12) : Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Test Result View

struct TestResultView: View {
    let attempt: StudentTestAttempt
    let test: FacultyTest
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Celebration
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill((attempt.isPassed ? Color.green : Color.orange).opacity(0.18))
                            .frame(width: 80, height: 80)
                        Image(systemName: attempt.isPassed ? "trophy.fill" : "chart.line.uptrend.xyaxis")
                            .font(.system(size: 36))
                            .foregroundStyle(attempt.isPassed ? .green : .orange)
                    }

                    Text(attempt.isPassed ? "Test Completed!" : "Needs Practice")
                        .font(.title2.bold())

                    Text(test.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                // Big Score Card
                VStack(spacing: 10) {
                    Text("\(attempt.score) / \(attempt.totalQuestions)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(attempt.isPassed ? .green : .orange)

                    Text(String(format: "%.1f%% Score", attempt.percentage))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 18))

                // Breakdown Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Correct Answers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(attempt.score)")
                            .font(.title2.bold())
                            .foregroundStyle(.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Incorrect Answers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(attempt.totalQuestions - attempt.score)")
                            .font(.title2.bold())
                            .foregroundStyle(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
                }

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Text("Return to Tests")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .padding(.top, 12)
            }
            .padding(24)
        }
        .navigationTitle("Result")
        .navigationBarTitleDisplayMode(.inline)
    }
}
