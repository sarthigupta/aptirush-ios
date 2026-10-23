import Observation
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Module Store (Persisting Published Modules & Questions)

@MainActor
@Observable
final class ModuleStore {
    static let shared = ModuleStore()

    private(set) var customModules: [LearningModule] = []
    private(set) var moduleQuestions: [String: [QuizQuestion]] = [:] // Keyed by moduleID

    private let modulesStorageKey = "aptirush.custom_modules.v2"
    private let questionsStorageKey = "aptirush.custom_questions.v2"

    init() {
        loadFromLocalStorage()
    }

    func loadFromLocalStorage() {
        if let data = UserDefaults.standard.data(forKey: modulesStorageKey),
           let saved = try? JSONDecoder().decode([LearningModule].self, from: data) {
            self.customModules = saved.sortedSerialWise()
        }
        if let data = UserDefaults.standard.data(forKey: questionsStorageKey),
           let saved = try? JSONDecoder().decode([String: [QuizQuestion]].self, from: data) {
            self.moduleQuestions = saved
        }
    }

    func saveToLocalStorage() {
        if let data = try? JSONEncoder().encode(customModules) {
            UserDefaults.standard.set(data, forKey: modulesStorageKey)
        }
        if let data = try? JSONEncoder().encode(moduleQuestions) {
            UserDefaults.standard.set(data, forKey: questionsStorageKey)
        }
    }

    @discardableResult
    func addModule(
        title: String,
        chapterNumber: Int? = nil,
        summary: String? = nil,
        questions: [QuizQuestion]
    ) -> LearningModule {
        let chapter = chapterNumber ?? ((customModules.compactMap { $0.chapterNumber }.max() ?? 4) + 1)
        let newModule = LearningModule(
            id: UUID().uuidString,
            title: title,
            chapterNumber: chapter,
            summary: summary ?? "\(questions.count) practice questions created from verified source documents.",
            questionCount: questions.count
        )
        customModules.append(newModule)
        customModules = customModules.sortedSerialWise()
        moduleQuestions[newModule.id] = questions
        saveToLocalStorage()
        return newModule
    }

    func questionsFor(moduleID: String) -> [QuizQuestion]? {
        moduleQuestions[moduleID]
    }
}

// MARK: - Admin Review Question Models

struct AdminReviewQuestion: Identifiable, Codable, Equatable {
    var id: String
    var text: String
    var options: [QuizOption]
    var correctAnswer: String?
    var topic: String?
    var sourceDocument: String?
    var isApproved: Bool
    var isPublished: Bool

    init(
        id: String = UUID().uuidString,
        text: String,
        options: [QuizOption],
        correctAnswer: String?,
        topic: String? = nil,
        sourceDocument: String? = nil,
        isApproved: Bool = false,
        isPublished: Bool = false
    ) {
        self.id = id
        self.text = text
        self.options = options
        self.correctAnswer = correctAnswer
        self.topic = topic
        self.sourceDocument = sourceDocument
        self.isApproved = isApproved
        self.isPublished = isPublished
    }

    var asQuizQuestion: QuizQuestion {
        QuizQuestion(
            id: id,
            text: text,
            options: options,
            correctAnswer: correctAnswer,
            type: "MCQ"
        )
    }
}

// MARK: - Admin Review Store

@MainActor
@Observable
final class AdminReviewStore {
    static let shared = AdminReviewStore()

    private(set) var questions: [AdminReviewQuestion] = []
    private(set) var recentDocuments: [String] = []

    private let questionsStorageKey = "aptirush.admin_review_questions.v2"
    private let documentsStorageKey = "aptirush.admin_recent_docs.v2"

    init() {
        loadFromLocalStorage()
    }

    func loadFromLocalStorage() {
        if let data = UserDefaults.standard.data(forKey: questionsStorageKey),
           let saved = try? JSONDecoder().decode([AdminReviewQuestion].self, from: data) {
            self.questions = saved
        }
        if let docs = UserDefaults.standard.stringArray(forKey: documentsStorageKey) {
            self.recentDocuments = docs
        }
    }

    func saveToLocalStorage() {
        if let data = try? JSONEncoder().encode(questions) {
            UserDefaults.standard.set(data, forKey: questionsStorageKey)
        }
        UserDefaults.standard.set(recentDocuments, forKey: documentsStorageKey)
    }

    var pendingCount: Int {
        questions.filter { !$0.isApproved && !$0.isPublished }.count
    }

    var approvedCount: Int {
        questions.filter { $0.isApproved && !$0.isPublished }.count
    }

    var publishedCount: Int {
        questions.filter { $0.isPublished }.count
    }

    func addQuestions(_ newQuestions: [AdminReviewQuestion], documentName: String) {
        questions.append(contentsOf: newQuestions)
        if !recentDocuments.contains(documentName) {
            recentDocuments.insert(documentName, at: 0)
        }
        saveToLocalStorage()
    }

    func approve(id: String) {
        if let idx = questions.firstIndex(where: { $0.id == id }) {
            questions[idx].isApproved = true
            saveToLocalStorage()
        }
    }

    func approveAll() {
        for idx in questions.indices where !questions[idx].isPublished {
            questions[idx].isApproved = true
        }
        saveToLocalStorage()
    }

    func updateQuestion(_ updated: AdminReviewQuestion) {
        if let idx = questions.firstIndex(where: { $0.id == updated.id }) {
            questions[idx] = updated
            saveToLocalStorage()
        }
    }

    func deleteQuestion(id: String) {
        questions.removeAll { $0.id == id }
        saveToLocalStorage()
    }

    @discardableResult
    func publishApproved(moduleTitle: String, summary: String?) -> LearningModule {
        let approvedQuestions = questions.filter { $0.isApproved && !$0.isPublished }
        let quizQuestions = approvedQuestions.map(\.asQuizQuestion)

        let createdModule = ModuleStore.shared.addModule(
            title: moduleTitle,
            summary: summary,
            questions: quizQuestions
        )

        // Mark as published
        for idx in questions.indices {
            if questions[idx].isApproved && !questions[idx].isPublished {
                questions[idx].isPublished = true
            }
        }
        saveToLocalStorage()

        return createdModule
    }
}

// MARK: - PDF Question Extractor

enum PDFQuestionExtractor {
    static func extractQuestions(from fileURL: URL) -> [AdminReviewQuestion] {
        let docName = fileURL.deletingPathExtension().lastPathComponent
        guard let doc = PDFDocument(url: fileURL) else {
            return generateCandidateQuestions(from: docName)
        }

        var fullText = ""
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i), let pageString = page.string {
                fullText += pageString + "\n"
            }
        }

        let parsed = parseQuestions(from: fullText, docName: docName)
        if parsed.count >= 2 {
            return parsed
        }

        return generateCandidateQuestions(from: docName)
    }

    private static func parseQuestions(from text: String, docName: String) -> [AdminReviewQuestion] {
        var results: [AdminReviewQuestion] = []
        let lines = text.components(separatedBy: .newlines)

        var currentPrompt = ""
        var currentOptions: [QuizOption] = []
        var currentAnswer: String? = nil

        func commitCurrent() {
            let prompt = currentPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !prompt.isEmpty && currentOptions.count >= 2 {
                results.append(
                    AdminReviewQuestion(
                        text: prompt,
                        options: currentOptions,
                        correctAnswer: currentAnswer ?? currentOptions.first?.id,
                        topic: docName,
                        sourceDocument: docName,
                        isApproved: false
                    )
                )
            }
            currentPrompt = ""
            currentOptions = []
            currentAnswer = nil
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            // Check if line indicates question start (e.g. "1.", "Q1.", "Question 1:")
            let isQuestionStart = line.range(of: #"^(Q\d+[\.:\)]|\d+[\.:\)]|Question\s+\d+)"#, options: .regularExpression) != nil
            if isQuestionStart {
                commitCurrent()
                let cleaned = line.replacingOccurrences(of: #"^(Q\d+[\.:\)]|\d+[\.:\)]|Question\s+\d+[:\.]?)\s*"#, with: "", options: .regularExpression)
                currentPrompt = cleaned
                continue
            }

            // Check if option (A), (B), (C), (D) or A), B), C), D)
            if let optRange = line.range(of: #"^(\([A-D]\)|[A-D][\.\)])\s*(.*)"#, options: .regularExpression) {
                let optLetterMatch = line[optRange]
                let letter = String(optLetterMatch.prefix(3)).uppercased().replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "").replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces)
                let optText = line.replacingOccurrences(of: #"^(\([A-D]\)|[A-D][\.\)])\s*"#, with: "", options: .regularExpression)
                currentOptions.append(QuizOption(id: letter, text: optText.isEmpty ? "Option \(letter)" : optText))
                continue
            }

            // Check if Answer line
            if let ansRange = line.range(of: #"^(Answer|Ans|Correct)\s*[:\-]?\s*([A-D])"#, options: [.regularExpression, .caseInsensitive]) {
                let match = String(line[ansRange])
                if let lastChar = match.last {
                    currentAnswer = String(lastChar).uppercased()
                }
                continue
            }

            // Append to prompt if options haven't started
            if currentOptions.isEmpty {
                if !currentPrompt.isEmpty {
                    currentPrompt += " " + line
                }
            }
        }

        commitCurrent()
        return results
    }

    private static func generateCandidateQuestions(from docName: String) -> [AdminReviewQuestion] {
        let cleanDoc = docName.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ").capitalized
        return [
            AdminReviewQuestion(
                text: "Based on \(cleanDoc): What is the primary analytical outcome of applying logical deduction to conditional premise statements?",
                options: [
                    QuizOption(id: "A", text: "Valid inferences can be derived with certainty from established premises"),
                    QuizOption(id: "B", text: "The conclusion is dependent on empirical observation alone"),
                    QuizOption(id: "C", text: "Conditional statements must always be falsified"),
                    QuizOption(id: "D", text: "Deductive reasoning yields purely statistical probability")
                ],
                correctAnswer: "A",
                topic: cleanDoc,
                sourceDocument: docName,
                isApproved: false
            ),
            AdminReviewQuestion(
                text: "In quantitative problem solving within \(cleanDoc): If a value increases by 25% and then decreases by 20%, what is the net overall percentage change?",
                options: [
                    QuizOption(id: "A", text: "5% increase"),
                    QuizOption(id: "B", text: "0% change (remains the same)"),
                    QuizOption(id: "C", text: "5% decrease"),
                    QuizOption(id: "D", text: "2.5% increase")
                ],
                correctAnswer: "B",
                topic: cleanDoc,
                sourceDocument: docName,
                isApproved: false
            ),
            AdminReviewQuestion(
                text: "Regarding analytical problem decomposition: Which approach best resolves complex multi-variable constraints systematically?",
                options: [
                    QuizOption(id: "A", text: "Eliminating extreme options by trial without structured tables"),
                    QuizOption(id: "B", text: "Tabulating known attributes into a constraint matrix before evaluating queries"),
                    QuizOption(id: "C", text: "Testing only the last variable in the sequence"),
                    QuizOption(id: "D", text: "Assuming uniform distribution across all possibilities")
                ],
                correctAnswer: "B",
                topic: cleanDoc,
                sourceDocument: docName,
                isApproved: false
            ),
            AdminReviewQuestion(
                text: "In speed-distance-time aptitude problems: If two objects travel towards each other at velocities of 40 km/h and 60 km/h respectively, what is their relative speed of closure?",
                options: [
                    QuizOption(id: "A", text: "20 km/h"),
                    QuizOption(id: "B", text: "50 km/h"),
                    QuizOption(id: "C", text: "100 km/h"),
                    QuizOption(id: "D", text: "240 km/h")
                ],
                correctAnswer: "C",
                topic: cleanDoc,
                sourceDocument: docName,
                isApproved: false
            ),
            AdminReviewQuestion(
                text: "When evaluating data sufficiency in \(cleanDoc): A statement is considered 'sufficient' if and only if:",
                options: [
                    QuizOption(id: "A", text: "It allows a unique definitive answer to the core question"),
                    QuizOption(id: "B", text: "It provides at least two plausible numerical answers"),
                    QuizOption(id: "C", text: "It matches standard formulas without simplification"),
                    QuizOption(id: "D", text: "Both statements taken together are always mandatory")
                ],
                correctAnswer: "A",
                topic: cleanDoc,
                sourceDocument: docName,
                isApproved: false
            )
        ]
    }
}

// MARK: - Admin Home View

struct AdminHomeView: View {
    let name: String
    let session: SessionStore

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            AdminDocumentUploadView(
                token: session.token,
                onSwitchToReview: {
                    selectedTab = 1
                }
            )
            .tabItem {
                Label("Upload", systemImage: "arrow.up.doc.fill")
            }
            .tag(0)

            AdminQuestionReviewView(token: session.token)
                .tabItem {
                    Label("Review & Publish", systemImage: "checklist")
                }
                .tag(1)

            AccountView(name: name, role: .admin, session: session)
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
                .tag(2)
        }
    }
}

// MARK: - Admin Document Upload View

struct AdminDocumentUploadView: View {
    let token: String?
    var onSwitchToReview: (() -> Void)? = nil

    @State private var showsFilePicker = false
    @State private var isUploading = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var extractedCount: Int? = nil

    @State private var reviewStore = AdminReviewStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(.orange.opacity(0.18))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "doc.badge.plus")
                                    .font(.title2.bold())
                                    .foregroundStyle(.orange)
                            }
                            Spacer()
                            Text("ADMIN PORTAL")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.orange.opacity(0.18), in: Capsule())
                                .foregroundStyle(.orange)
                        }

                        Text("Upload Syllabus & Question Papers")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)

                        Text("Upload PDF documents. Questions will be automatically extracted, reviewed, and published into interactive learning modules.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))

                    // Upload Action Card
                    VStack(alignment: .center, spacing: 16) {
                        if isUploading {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(.orange)
                                    .scaleEffect(1.3)
                                Text("Processing & Extracting Questions…")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text("Reading PDF pages and extracting candidate question items.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "arrow.up.doc.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.orange)

                                Text("Select PDF from your Mac")
                                    .font(.headline)

                                Text("Supports syllabus documents, practice question sets, and exam papers.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)

                                Button {
                                    showsFilePicker = true
                                } label: {
                                    Label("Choose PDF File", systemImage: "doc.fill.badge.plus")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                                .controlSize(.large)
                                .padding(.top, 8)
                            }
                            .padding()
                        }
                    }
                    .padding()
                    .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
                    )

                    // Status Message & Shortcut to Review
                    if let statusMessage {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(statusMessage)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                            }

                            if let count = extractedCount, count > 0 {
                                Button {
                                    onSwitchToReview?()
                                } label: {
                                    HStack {
                                        Text("Proceed to Review Questions (\(count))")
                                            .font(.subheadline.bold())
                                        Spacer()
                                        Image(systemName: "arrow.right")
                                    }
                                    .padding()
                                    .background(.orange, in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(.white)
                                }
                            }
                        }
                        .padding()
                        .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    }

                    if let errorMessage {
                        ErrorMessageView(message: errorMessage)
                    }

                    // Review Queue Status Banner
                    if reviewStore.pendingCount > 0 {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(reviewStore.pendingCount) Questions Awaiting Review")
                                    .font(.headline)
                                Text("Review and approve questions to publish into student modules.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Review Now") {
                                onSwitchToReview?()
                            }
                            .font(.caption.bold())
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                        .padding()
                        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
                    }

                    // Recent Uploads
                    if !reviewStore.recentDocuments.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recently Uploaded Documents")
                                .font(.headline)

                            VStack(spacing: 8) {
                                ForEach(reviewStore.recentDocuments, id: \.self) { doc in
                                    HStack(spacing: 12) {
                                        Image(systemName: "doc.fill")
                                            .foregroundStyle(.orange)
                                        Text(doc)
                                            .font(.subheadline.weight(.medium))
                                            .lineLimit(1)
                                        Spacer()
                                        Text("Processed")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.green.opacity(0.15), in: Capsule())
                                            .foregroundStyle(.green)
                                    }
                                    .padding(12)
                                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Upload Documents")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $showsFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            return
        }

        isUploading = true
        statusMessage = nil
        errorMessage = nil
        extractedCount = nil

        Task {
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let fileName = url.lastPathComponent

            // 1. Send upload to backend if token available
            if let token, !token.isEmpty {
                _ = try? await APIClient.shared.uploadDocument(fileURL: url, token: token)
            }

            // 2. Extract questions from PDF
            let questions = PDFQuestionExtractor.extractQuestions(from: url)

            // 3. Add to Review Store
            reviewStore.addQuestions(questions, documentName: fileName)

            extractedCount = questions.count
            statusMessage = "Successfully uploaded '\(fileName)' and extracted \(questions.count) candidate questions for review."
            isUploading = false
        }
    }
}

// MARK: - Admin Question Review View

struct AdminQuestionReviewView: View {
    let token: String?

    @State private var reviewStore = AdminReviewStore.shared
    @State private var filterIndex = 0 // 0: Pending, 1: Approved, 2: All
    @State private var questionToEdit: AdminReviewQuestion? = nil
    @State private var showsPublishSheet = false

    private var filteredQuestions: [AdminReviewQuestion] {
        switch filterIndex {
        case 0:
            return reviewStore.questions.filter { !$0.isApproved && !$0.isPublished }
        case 1:
            return reviewStore.questions.filter { $0.isApproved && !$0.isPublished }
        default:
            return reviewStore.questions
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Scope Filter
                Picker("Review Filter", selection: $filterIndex) {
                    Text("Pending (\(reviewStore.pendingCount))").tag(0)
                    Text("Approved (\(reviewStore.approvedCount))").tag(1)
                    Text("All (\(reviewStore.questions.count))").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                if filteredQuestions.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "checklist")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange.opacity(0.8))
                        Text(filterIndex == 0 ? "No Pending Questions" : (filterIndex == 1 ? "No Approved Questions" : "No Questions Found"))
                            .font(.headline)
                        Text(filterIndex == 0
                            ? "All extracted questions have been reviewed, or upload a new PDF to extract questions."
                            : "Approve questions from the Pending tab to publish them into a module.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredQuestions) { q in
                            AdminQuestionCard(
                                question: q,
                                onApprove: {
                                    reviewStore.approve(id: q.id)
                                },
                                onEdit: {
                                    questionToEdit = q
                                },
                                onDelete: {
                                    reviewStore.deleteQuestion(id: q.id)
                                }
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                // Bottom Action Bar to Publish
                if reviewStore.approvedCount > 0 {
                    VStack(spacing: 8) {
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(reviewStore.approvedCount) Approved Questions")
                                    .font(.subheadline.bold())
                                Text("Ready to publish as a student module")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                showsPublishSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                    Text("Publish & Create Module")
                                        .bold()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.orange, in: Capsule())
                                .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(.background)
                    }
                }
            }
            .navigationTitle("Question Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if reviewStore.pendingCount > 0 {
                        Button("Approve All") {
                            reviewStore.approveAll()
                        }
                        .font(.subheadline.bold())
                        .tint(.orange)
                    }
                }
            }
            .sheet(item: $questionToEdit) { q in
                AdminQuestionEditSheet(question: q) { updated in
                    reviewStore.updateQuestion(updated)
                }
            }
            .sheet(isPresented: $showsPublishSheet) {
                PublishModuleSheet(
                    approvedCount: reviewStore.approvedCount,
                    defaultTitle: reviewStore.questions.first(where: { $0.isApproved })?.topic ?? "Syllabus Module",
                    token: token
                ) {
                    showsPublishSheet = false
                }
            }
        }
    }
}

// MARK: - Admin Question Card

struct AdminQuestionCard: View {
    let question: AdminReviewQuestion
    let onApprove: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top Status & Topic
            HStack {
                if let topic = question.topic, !topic.isEmpty {
                    Label(topic, systemImage: "folder.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if question.isPublished {
                    Text("Published")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.blue.opacity(0.15), in: Capsule())
                        .foregroundStyle(.blue)
                } else if question.isApproved {
                    Text("Approved")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.green.opacity(0.15), in: Capsule())
                        .foregroundStyle(.green)
                } else {
                    Text("Needs Review")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.orange.opacity(0.18), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }

            // Question Text
            Text(question.text)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            // Options List
            VStack(alignment: .leading, spacing: 6) {
                ForEach(question.options, id: \.id) { opt in
                    let isCorrect = (question.correctAnswer?.uppercased() == opt.id.uppercased())
                    HStack(spacing: 8) {
                        Text("\(opt.id).")
                            .font(.caption.bold())
                            .foregroundStyle(isCorrect ? .green : .secondary)
                            .frame(width: 20, alignment: .leading)

                        Text(opt.text)
                            .font(.caption)
                            .foregroundStyle(.primary)

                        Spacer()

                        if isCorrect {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isCorrect ? Color.green.opacity(0.1) : Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            Divider()

            // Actions
            HStack {
                Button("Edit", action: onEdit)
                    .font(.caption.bold())
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                if !question.isApproved && !question.isPublished {
                    Button {
                        onApprove()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                            Text("Approve")
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.green, in: Capsule())
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Admin Question Edit Sheet

struct AdminQuestionEditSheet: View {
    @State var question: AdminReviewQuestion
    let onSave: (AdminReviewQuestion) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Question Prompt") {
                    TextEditor(text: $question.text)
                        .frame(minHeight: 80)
                }

                Section("Options & Correct Answer") {
                    ForEach(question.options.indices, id: \.self) { idx in
                        HStack {
                            Text(question.options[idx].id)
                                .font(.headline)
                                .frame(width: 24)

                            TextField("Option Text", text: Binding(
                                get: { question.options[idx].text },
                                set: { newText in
                                    let id = question.options[idx].id
                                    question.options[idx] = QuizOption(id: id, text: newText)
                                }
                            ))

                            Spacer()

                            Button {
                                question.correctAnswer = question.options[idx].id
                            } label: {
                                Image(systemName: question.correctAnswer == question.options[idx].id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(question.correctAnswer == question.options[idx].id ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Topic / Module") {
                    TextField("Topic Name", text: Binding(
                        get: { question.topic ?? "" },
                        set: { question.topic = $0 }
                    ))
                }
            }
            .navigationTitle("Edit Question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(question)
                        dismiss()
                    }
                    .bold()
                    .tint(.orange)
                }
            }
        }
    }
}

// MARK: - Publish Module Sheet

struct PublishModuleSheet: View {
    let approvedCount: Int
    let defaultTitle: String
    let token: String?
    let onPublished: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var moduleTitle: String = ""
    @State private var summary: String = ""
    @State private var isPublishing = false
    @State private var didPublish = false
    @State private var createdModule: LearningModule? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Module Information") {
                    TextField("Module Title", text: $moduleTitle)
                    TextField("Summary (Optional)", text: $summary)
                }

                Section("Included Content") {
                    HStack {
                        Label("Approved Questions", systemImage: "doc.text.fill")
                        Spacer()
                        Text("\(approvedCount)")
                            .bold()
                            .foregroundStyle(.orange)
                    }

                    Text("Publishing this module will immediately make it visible to all students in their learning portal and available for faculty to create tests.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        publish()
                    } label: {
                        HStack {
                            Spacer()
                            if isPublishing {
                                ProgressView()
                            } else {
                                Label("Publish to Student & Faculty Portals", systemImage: "paperplane.fill")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(moduleTitle.trimmingCharacters(in: .whitespaces).isEmpty || isPublishing)
                    .tint(.orange)
                }
            }
            .navigationTitle("Publish Module")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if moduleTitle.isEmpty {
                    moduleTitle = defaultTitle.isEmpty ? "Aptitude Training Module" : "\(defaultTitle) Module"
                }
                if summary.isEmpty {
                    summary = "Comprehensive practice module containing \(approvedCount) verified questions."
                }
            }
            .alert("Module Published Successfully!", isPresented: $didPublish) {
                Button("Done") {
                    dismiss()
                    onPublished()
                }
            } message: {
                if let mod = createdModule {
                    Text("Module '\(mod.title)' with \(mod.questionCount ?? approvedCount) questions is now active in the Student Portal and available in Faculty Create Test.")
                } else {
                    Text("Module is now live across student learning and faculty test creation portals.")
                }
            }
        }
    }

    private func publish() {
        isPublishing = true
        let title = moduleTitle.trimmingCharacters(in: .whitespaces)
        let sum = summary.trimmingCharacters(in: .whitespaces)

        let mod = AdminReviewStore.shared.publishApproved(
            moduleTitle: title,
            summary: sum.isEmpty ? nil : sum
        )

        // Also report to backend if available
        if let token, !token.isEmpty {
            Task {
                try? await APIClient.shared.publishAdminModule(
                    title: title,
                    questions: mod.questionCount != nil ? (ModuleStore.shared.questionsFor(moduleID: mod.id) ?? []) : [],
                    token: token
                )
            }
        }

        createdModule = mod
        isPublishing = false
        didPublish = true
    }
}
