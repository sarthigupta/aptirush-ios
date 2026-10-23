import Observation
import SwiftUI

struct LearningModule: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let chapterNumber: Int?
    let summary: String?
    let questionCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case objectID = "_id"
        case title
        case name
        case chapterNumber
        case summary
        case description
        case questionCount
        case question_count
        case count = "_count"
    }

    private struct CountContainer: Decodable, Hashable {
        let questions: Int?
    }

    init(id: String, title: String, chapterNumber: Int? = nil, summary: String? = nil, questionCount: Int? = nil) {
        self.id = id
        self.title = title
        self.chapterNumber = chapterNumber
        self.summary = summary
        self.questionCount = questionCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decode(String.self, forKey: .objectID)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? "Untitled Module"
        chapterNumber = try container.decodeIfPresent(Int.self, forKey: .chapterNumber)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .description)
        let nestedCount = try? container.decodeIfPresent(CountContainer.self, forKey: .count)
        questionCount = try container.decodeIfPresent(Int.self, forKey: .questionCount)
            ?? container.decodeIfPresent(Int.self, forKey: .question_count)
            ?? nestedCount?.questions
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(chapterNumber, forKey: .chapterNumber)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encodeIfPresent(questionCount, forKey: .questionCount)
    }
}

struct ModulesResponse: Decodable {
    let modules: [LearningModule]

    enum CodingKeys: String, CodingKey {
        case modules
        case data
    }

    init(from decoder: Decoder) throws {
        if let modules = try? decoder.singleValueContainer().decode([LearningModule].self) {
            self.modules = modules
            return
        }

        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self.modules = []
            return
        }
        self.modules = (try? container.decodeIfPresent([LearningModule].self, forKey: .modules))
            ?? (try? container.decodeIfPresent([LearningModule].self, forKey: .data))
            ?? []
    }
}

struct QuizOption: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let text: String

    init(id: String, text: String) {
        self.id = id
        self.text = text
    }

    enum CodingKeys: String, CodingKey {
        case id
        case key
        case optionKey
        case text
        case label
        case value
        case optionText
    }

    init(from decoder: Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self) {
            self.id = text
            self.text = text
            return
        }

        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self.id = UUID().uuidString
            self.text = ""
            return
        }

        var textCandidate = try? container.decodeIfPresent(String.self, forKey: .text)
        if textCandidate == nil {
            textCandidate = try? container.decodeIfPresent(String.self, forKey: .label)
        }
        if textCandidate == nil {
            textCandidate = try? container.decodeIfPresent(String.self, forKey: .value)
        }
        if textCandidate == nil {
            textCandidate = try? container.decodeIfPresent(String.self, forKey: .optionText)
        }
        let resolvedText = textCandidate ?? ""
        self.text = resolvedText

        var keyCandidate = try? container.decodeIfPresent(String.self, forKey: .key)
        if keyCandidate == nil {
            keyCandidate = try? container.decodeIfPresent(String.self, forKey: .optionKey)
        }
        if keyCandidate == nil {
            keyCandidate = try? container.decodeIfPresent(String.self, forKey: .id)
        }
        self.id = keyCandidate ?? resolvedText
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
    }
}

struct QuizQuestion: Codable, Identifiable, Equatable {
    let id: String
    let text: String
    let options: [QuizOption]
    let correctAnswer: String?
    let type: String?

    var isTextAnswer: Bool {
        if let type, type.uppercased() == "TITA" {
            return true
        }
        return options.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case id
        case objectID = "_id"
        case text
        case questionText
        case question_text
        case question
        case title
        case prompt
        case options
        case correctAnswer
        case correct_answer
        case type
    }

    init(id: String, text: String, options: [QuizOption], correctAnswer: String?, type: String?) {
        self.id = id
        self.text = text
        self.options = options
        self.correctAnswer = correctAnswer
        self.type = type
    }

    init(from decoder: Decoder) throws {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self.id = UUID().uuidString
            self.text = ""
            self.options = []
            self.correctAnswer = nil
            self.type = nil
            return
        }

        var idCandidate = try? container.decodeIfPresent(String.self, forKey: .id)
        if idCandidate == nil {
            idCandidate = try? container.decodeIfPresent(String.self, forKey: .objectID)
        }
        if idCandidate == nil, let intID = try? container.decodeIfPresent(Int.self, forKey: .id) {
            idCandidate = String(intID)
        }
        self.id = idCandidate ?? UUID().uuidString

        var textCandidate = try? container.decodeIfPresent(String.self, forKey: .text)
        if textCandidate == nil {
            textCandidate = try? container.decodeIfPresent(String.self, forKey: .questionText)
        }
        if textCandidate == nil {
            textCandidate = try? container.decodeIfPresent(String.self, forKey: .question_text)
        }
        if textCandidate == nil {
            textCandidate = try? container.decodeIfPresent(String.self, forKey: .question)
        }
        if textCandidate == nil {
            textCandidate = try? container.decodeIfPresent(String.self, forKey: .title)
        }
        if textCandidate == nil {
            textCandidate = try? container.decodeIfPresent(String.self, forKey: .prompt)
        }
        self.text = textCandidate ?? ""

        if let stringAns = try? container.decodeIfPresent(String.self, forKey: .correctAnswer) {
            self.correctAnswer = stringAns
        } else if let intAns = try? container.decodeIfPresent(Int.self, forKey: .correctAnswer) {
            self.correctAnswer = String(intAns)
        } else if let stringAns2 = try? container.decodeIfPresent(String.self, forKey: .correct_answer) {
            self.correctAnswer = stringAns2
        } else if let intAns2 = try? container.decodeIfPresent(Int.self, forKey: .correct_answer) {
            self.correctAnswer = String(intAns2)
        } else {
            self.correctAnswer = nil
        }

        self.type = try? container.decodeIfPresent(String.self, forKey: .type)

        if let dictOptions = try? container.decodeIfPresent([String: String].self, forKey: .options) {
            let sortedKeys = dictOptions.keys.sorted()
            self.options = sortedKeys.map { key in
                QuizOption(id: key, text: dictOptions[key] ?? "")
            }
        } else if let arrayOptions = try? container.decodeIfPresent([QuizOption].self, forKey: .options) {
            self.options = arrayOptions
        } else if let stringOptions = try? container.decodeIfPresent([String].self, forKey: .options) {
            self.options = stringOptions.enumerated().map { index, str in
                let key = String(UnicodeScalar(65 + index) ?? "A")
                return QuizOption(id: key, text: str)
            }
        } else {
            self.options = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(options, forKey: .options)
        try container.encodeIfPresent(correctAnswer, forKey: .correctAnswer)
        try container.encodeIfPresent(type, forKey: .type)
    }
}

struct ModuleQuizResponse: Decodable {
    let questions: [QuizQuestion]

    init(questions: [QuizQuestion]) {
        self.questions = questions
    }

    enum CodingKeys: String, CodingKey {
        case questions
        case data
        case module
    }

    init(from decoder: Decoder) throws {
        if let directList = try? decoder.singleValueContainer().decode([QuizQuestion].self) {
            self.questions = directList
            return
        }

        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self.questions = []
            return
        }

        if let directQuestions = try? container.decodeIfPresent([QuizQuestion].self, forKey: .questions) {
            self.questions = directQuestions
            return
        }

        if let dataList = try? container.decodeIfPresent([QuizQuestion].self, forKey: .data) {
            self.questions = dataList
            return
        }

        self.questions = []
    }

    static func parse(from data: Data) -> ModuleQuizResponse {
        if let decoded = try? JSONDecoder().decode(ModuleQuizResponse.self, from: data), !decoded.questions.isEmpty {
            return decoded
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return ModuleQuizResponse(questions: [])
        }

        var rawQuestions: [[String: Any]] = []

        if let array = jsonObject as? [[String: Any]] {
            rawQuestions = array
        } else if let dict = jsonObject as? [String: Any] {
            if let qs = dict["questions"] as? [[String: Any]] {
                rawQuestions = qs
            } else if let d = dict["data"] as? [String: Any], let qs = d["questions"] as? [[String: Any]] {
                rawQuestions = qs
            } else if let qs = dict["data"] as? [[String: Any]] {
                rawQuestions = qs
            } else if let m = dict["module"] as? [String: Any], let qs = m["questions"] as? [[String: Any]] {
                rawQuestions = qs
            }
        }

        let parsedQuestions: [QuizQuestion] = rawQuestions.compactMap { item in
            let id = (item["id"] as? String)
                ?? (item["_id"] as? String)
                ?? (item["id"] as? Int).map(String.init)
                ?? UUID().uuidString

            let text = (item["questionText"] as? String)
                ?? (item["text"] as? String)
                ?? (item["question_text"] as? String)
                ?? (item["question"] as? String)
                ?? (item["title"] as? String)
                ?? (item["prompt"] as? String)
                ?? ""

            var options: [QuizOption] = []
            if let dictOpts = item["options"] as? [String: Any] {
                let sortedKeys = dictOpts.keys.sorted()
                options = sortedKeys.map { k in
                    QuizOption(id: k, text: "\(dictOpts[k] ?? "")")
                }
            } else if let arrOpts = item["options"] as? [[String: Any]] {
                options = arrOpts.enumerated().map { idx, opt in
                    let key = (opt["key"] as? String)
                        ?? (opt["id"] as? String)
                        ?? String(UnicodeScalar(65 + idx) ?? "A")
                    let t = (opt["text"] as? String)
                        ?? (opt["label"] as? String)
                        ?? (opt["value"] as? String)
                        ?? ""
                    return QuizOption(id: key, text: t)
                }
            } else if let strOpts = item["options"] as? [String] {
                options = strOpts.enumerated().map { idx, str in
                    let key = String(UnicodeScalar(65 + idx) ?? "A")
                    return QuizOption(id: key, text: str)
                }
            }

            let correctAnswer: String? = {
                if let s = item["correctAnswer"] as? String { return s }
                if let i = item["correctAnswer"] as? Int { return String(i) }
                if let s = item["correct_answer"] as? String { return s }
                if let i = item["correct_answer"] as? Int { return String(i) }
                return nil
            }()

            let type = item["type"] as? String

            return QuizQuestion(id: id, text: text, options: options, correctAnswer: correctAnswer, type: type)
        }

        return ModuleQuizResponse(questions: parsedQuestions)
    }
}

typealias AttemptSubmission = QuizAttemptSubmission

struct QuizAttemptMistake: Codable {
    let questionId: String
    let userAnswer: String
}

struct QuizAttemptSubmission: Encodable {
    let moduleId: String
    let score: Int
    let total: Int
    let customTestId: String?
    let durationMs: Int
    let mistakes: [QuizAttemptMistake]
}

struct QuizAttemptResult: Decodable {
    let id: String?
    let score: Int?
}

struct StudentAnalytics: Codable {
    let elo: Int?
    let weakness: String?
    let mistakeCount: Int?
    let currentStreak: Int?
    let longestStreak: Int?
    let testsCompletedToday: Int?
    let dailyActivity: [String: Int]?
}

struct LeaderboardEntry: Codable, Identifiable {
    let id: String
    let name: String
    let affiliation: String?
    let elo: Int?
    let winRate: String?
    let avgSpeed: String?
    let accuracy: String?
}

struct MistakeVaultItem: Decodable, Identifiable {
    let id: String
    let questionText: String
    let options: [QuizOption]
    let correctAnswer: String?
    let userAnswer: String?
    let date: String?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case id
        case questionText
        case options
        case correctAnswer
        case userAnswer
        case date
        case type
    }

    init(id: String, questionText: String, options: [QuizOption], correctAnswer: String?, userAnswer: String?, date: String?, type: String?) {
        self.id = id
        self.questionText = questionText
        self.options = options
        self.correctAnswer = correctAnswer
        self.userAnswer = userAnswer
        self.date = date
        self.type = type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        self.questionText = (try? container.decodeIfPresent(String.self, forKey: .questionText)) ?? ""
        self.correctAnswer = try? container.decodeIfPresent(String.self, forKey: .correctAnswer)
        self.userAnswer = try? container.decodeIfPresent(String.self, forKey: .userAnswer)
        self.date = try? container.decodeIfPresent(String.self, forKey: .date)
        self.type = try? container.decodeIfPresent(String.self, forKey: .type)

        if let dict = try? container.decodeIfPresent([String: String].self, forKey: .options) {
            self.options = dict.keys.sorted().map { QuizOption(id: $0, text: dict[$0] ?? "") }
        } else if let arr = try? container.decodeIfPresent([QuizOption].self, forKey: .options) {
            self.options = arr
        } else if let strArr = try? container.decodeIfPresent([String].self, forKey: .options) {
            self.options = strArr.enumerated().map { idx, str in
                let key = String(UnicodeScalar(65 + idx) ?? "A")
                return QuizOption(id: key, text: str)
            }
        } else {
            self.options = []
        }
    }

    static func parseList(from data: Data) -> [MistakeVaultItem] {
        if let decoded = try? JSONDecoder().decode([MistakeVaultItem].self, from: data) {
            return decoded
        }

        guard let jsonArray = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            return []
        }

        return jsonArray.compactMap { dict in
            let id = (dict["id"] as? String) ?? UUID().uuidString
            let text = (dict["questionText"] as? String) ?? (dict["text"] as? String) ?? ""
            let correct = dict["correctAnswer"] as? String
            let userAns = dict["userAnswer"] as? String
            let date = dict["date"] as? String
            let type = dict["type"] as? String

            var opts: [QuizOption] = []
            if let d = dict["options"] as? [String: Any] {
                opts = d.keys.sorted().map { QuizOption(id: $0, text: "\(d[$0] ?? "")") }
            } else if let arr = dict["options"] as? [[String: Any]] {
                opts = arr.enumerated().map { idx, item in
                    let key = (item["key"] as? String) ?? (item["id"] as? String) ?? String(UnicodeScalar(65 + idx) ?? "A")
                    let val = (item["text"] as? String) ?? (item["value"] as? String) ?? ""
                    return QuizOption(id: key, text: val)
                }
            } else if let strArr = dict["options"] as? [String] {
                opts = strArr.enumerated().map { idx, str in
                    let key = String(UnicodeScalar(65 + idx) ?? "A")
                    return QuizOption(id: key, text: str)
                }
            }

            return MistakeVaultItem(
                id: id,
                questionText: text,
                options: opts,
                correctAnswer: correct,
                userAnswer: userAns,
                date: date,
                type: type
            )
        }
    }
}

@MainActor
@Observable
final class StudentModulesViewModel {
    private(set) var modules: [LearningModule] = []
    private(set) var isLoading: Bool = false
    var errorMessage: String?

    func load(token: String?) async {
        let rawToken = token ?? KeychainStore.token()
        guard let activeToken = rawToken?.trimmingCharacters(in: .whitespacesAndNewlines), !activeToken.isEmpty else {
            errorMessage = "Your session has expired. Please sign in again."
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            modules = try await APIClient.shared.studentModules(token: activeToken)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

@MainActor
@Observable
final class QuizViewModel {
    private(set) var questions: [QuizQuestion] = []
    private(set) var score: Int = 0
    private(set) var isLoading: Bool = true
    private(set) var isSubmitting: Bool = false
    private(set) var didSubmit: Bool = false
    var errorMessage: String?
    var selectedAnswers: [String: String] = [:]
    private var startedAt: Date = .now

    var answeredCount: Int {
        selectedAnswers.values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    var canSubmit: Bool {
        !questions.isEmpty && questions.allSatisfy { q in
            guard let ans = selectedAnswers[q.id] else { return false }
            return !ans.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func load(moduleID: String, token: String?) async {
        let rawToken = token ?? KeychainStore.token()
        guard let activeToken = rawToken?.trimmingCharacters(in: .whitespacesAndNewlines), !activeToken.isEmpty else {
            errorMessage = "Your session has expired. Please sign in again."
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        selectedAnswers = [:]
        didSubmit = false
        startedAt = .now

        do {
            let response = try await APIClient.shared.moduleQuiz(id: moduleID, token: activeToken)
            questions = response.questions
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func select(optionID: String, for questionID: String) {
        guard !didSubmit else {
            return
        }

        selectedAnswers[questionID] = optionID
    }

    func reset() {
        didSubmit = false
        selectedAnswers = [:]
        errorMessage = nil
        startedAt = .now
    }

    func submit(moduleID: String, token: String?) async {
        guard canSubmit, !isSubmitting else {
            return
        }

        let rawToken = token ?? KeychainStore.token()
        guard let activeToken = rawToken?.trimmingCharacters(in: .whitespacesAndNewlines), !activeToken.isEmpty else {
            errorMessage = "Your session has expired. Please sign in again."
            return
        }

        isSubmitting = true
        errorMessage = nil

        var calculatedScore = 0
        var mistakes: [QuizAttemptMistake] = []

        for question in questions {
            let chosen = (selectedAnswers[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let correct = (question.correctAnswer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            let isCorrect: Bool
            if chosen.isEmpty || correct.isEmpty {
                isCorrect = false
            } else if chosen.caseInsensitiveCompare(correct) == .orderedSame {
                isCorrect = true
            } else if let matchingOption = question.options.first(where: {
                $0.id.caseInsensitiveCompare(chosen) == .orderedSame || $0.text.caseInsensitiveCompare(chosen) == .orderedSame
            }), (matchingOption.id.caseInsensitiveCompare(correct) == .orderedSame || matchingOption.text.caseInsensitiveCompare(correct) == .orderedSame) {
                isCorrect = true
            } else {
                isCorrect = false
            }

            if isCorrect {
                calculatedScore += 1
            } else {
                let answerRecorded = chosen.isEmpty ? "Unanswered" : chosen
                mistakes.append(QuizAttemptMistake(questionId: question.id, userAnswer: answerRecorded))
            }
        }

        let elapsedMs = max(1000, Int(Date().timeIntervalSince(startedAt) * 1000))
        let payload = QuizAttemptSubmission(
            moduleId: moduleID,
            score: calculatedScore,
            total: questions.count,
            customTestId: nil,
            durationMs: elapsedMs,
            mistakes: mistakes
        )

        do {
            try await APIClient.shared.submitAttempt(payload, token: activeToken)
            score = calculatedScore
            didSubmit = true
        } catch {
            score = calculatedScore
            didSubmit = true
        }

        isSubmitting = false
    }
}

struct StudentModulesView: View {
    let token: String?
    @State private var model = StudentModulesViewModel()

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView("Loading modules…")
            } else if let errorMessage = model.errorMessage {
                LearningErrorView(message: errorMessage) {
                    Task {
                        await model.load(token: token)
                    }
                }
            } else if model.modules.isEmpty {
                ContentUnavailableView(
                    "No Modules Yet",
                    systemImage: "book.closed",
                    description: Text("Your available learning modules will appear here.")
                )
            } else {
                List(model.modules) { module in
                    NavigationLink(value: module) {
                        ModuleRowView(
                            title: module.title,
                            chapterNumber: module.chapterNumber,
                            summary: module.summary,
                            questionCount: module.questionCount
                        )
                    }
                }
                .listStyle(.plain)
                .navigationDestination(for: LearningModule.self) { module in
                    ModuleQuizView(
                        moduleID: module.id,
                        moduleTitle: module.title,
                        token: token ?? KeychainStore.token()
                    )
                }
            }
        }
        .navigationTitle("Modules")
        .task {
            if model.modules.isEmpty {
                await model.load(token: token)
            }
        }
        .refreshable {
            await model.load(token: token)
        }
    }
}

struct ModuleRowView: View {
    let title: String
    let chapterNumber: Int?
    let summary: String?
    let questionCount: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let chapterNumber {
                    Text("Chapter \(chapterNumber)")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
                Text(title)
                    .font(.headline)
            }

            if let summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let questionCount {
                Label("\(questionCount) questions", systemImage: "checklist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ModuleQuizView: View {
    let moduleID: String
    let moduleTitle: String
    let token: String?
    @State private var model = QuizViewModel()

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView("Loading questions…")
            } else if model.didSubmit {
                QuizResultView(
                    score: model.score,
                    total: model.questions.count,
                    onRetake: {
                        model.reset()
                    }
                )
            } else if let errorMessage = model.errorMessage {
                LearningErrorView(message: errorMessage) {
                    Task {
                        await model.load(moduleID: moduleID, token: token)
                    }
                }
            } else if model.questions.isEmpty {
                ContentUnavailableView(
                    "No Questions Available",
                    systemImage: "questionmark.circle",
                    description: Text("This module does not have questions yet.")
                )
            } else {
                QuizQuestionList(
                    questions: model.questions,
                    selectedAnswers: model.selectedAnswers,
                    isSubmitting: model.isSubmitting,
                    canSubmit: model.canSubmit,
                    onSelection: model.select,
                    onSubmit: {
                        Task {
                            await model.submit(moduleID: moduleID, token: token)
                        }
                    }
                )
            }
        }
        .navigationTitle(moduleTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: moduleID) {
            await model.load(moduleID: moduleID, token: token)
        }
        .refreshable {
            await model.load(moduleID: moduleID, token: token)
        }
    }
}

struct QuizQuestionList: View {
    let questions: [QuizQuestion]
    let selectedAnswers: [String: String]
    let isSubmitting: Bool
    let canSubmit: Bool
    let onSelection: (String, String) -> Void
    let onSubmit: () -> Void

    var answeredCount: Int {
        selectedAnswers.values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                QuizProgressHeader(answered: answeredCount, total: questions.count)

                ForEach(Array(questions.indices), id: \.self) { index in
                    let question = questions[index]
                    QuizQuestionCard(
                        number: index + 1,
                        question: question,
                        selectedOptionID: selectedAnswers[question.id],
                        onSelection: onSelection
                    )
                }

                Button(action: onSubmit) {
                    Group {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Submit Attempt")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isSubmitting || !canSubmit)
            }
            .padding()
        }
    }
}

struct QuizProgressHeader: View {
    let answered: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(answered) of \(total) answered")
                .font(.headline)
            ProgressView(value: Double(answered), total: Double(total))
        }
    }
}

struct QuizQuestionCard: View {
    let number: Int
    let question: QuizQuestion
    let selectedOptionID: String?
    let onSelection: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Question \(number)")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)

                if let type = question.type {
                    Text(type)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.fill.secondary, in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }

            Text(question.text)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            if question.isTextAnswer {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Answer")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    TextField(
                        "Type your answer...",
                        text: Binding(
                            get: { selectedOptionID ?? "" },
                            set: { onSelection($0, question.id) }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(question.options) { option in
                        QuizOptionButton(
                            id: option.id,
                            text: option.text,
                            isSelected: selectedOptionID == option.id,
                            onSelection: {
                                onSelection(option.id, question.id)
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct QuizOptionButton: View {
    let id: String
    let text: String
    let isSelected: Bool
    let onSelection: () -> Void

    var body: some View {
        Button(action: onSelection) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? .orange : .secondary)

                if !id.isEmpty && id.count <= 2 {
                    Text(id + ".")
                        .font(.subheadline.bold())
                        .foregroundStyle(isSelected ? .orange : .primary)
                }

                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange.opacity(0.12) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

struct QuizResultView: View {
    let score: Int
    let total: Int
    var onRetake: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label("Attempt Submitted", systemImage: "checkmark.seal.fill")
        } description: {
            Text("You scored \(score) out of \(total).")
        } actions: {
            if let onRetake {
                Button("Retake Quiz", action: onRetake)
                    .buttonStyle(.borderedProminent)
            }
        }
        .foregroundStyle(.primary)
    }
}

struct LearningErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Unable to Load Learning", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview("Quiz List") {
    QuizQuestionList(
        questions: [
            QuizQuestion(
                id: "1",
                text: "What is 2 + 2?",
                options: [
                    QuizOption(id: "A", text: "3"),
                    QuizOption(id: "B", text: "4"),
                    QuizOption(id: "C", text: "5")
                ],
                correctAnswer: "B",
                type: "MCQ"
            )
        ],
        selectedAnswers: [:],
        isSubmitting: false,
        canSubmit: true,
        onSelection: { _, _ in },
        onSubmit: {}
    )
}
