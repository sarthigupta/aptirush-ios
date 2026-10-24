import Foundation
import Observation
import Security
import SwiftUI

enum AppConfiguration {
    #if DEBUG
    static let apiBaseURL = URL(string: "https://aptirush.onrender.com/api")!
    #else
    static let apiBaseURL = URL(string: "https://aptirush.onrender.com/api")!
    #endif
}

enum UserRole: String, Codable, CaseIterable, Equatable {
    case student = "STUDENT"
    case faculty = "FACULTY"
    case admin = "ADMIN"

    var title: String {
        switch self {
        case .student: "Student"
        case .faculty: "Faculty"
        case .admin: "Admin"
        }
    }
}

struct UserProfile: Codable, Equatable {
    let id: String
    let name: String
    let email: String
    let role: UserRole

    enum CodingKeys: String, CodingKey {
        case id
        case _id
        case name
        case email
        case role
    }

    init(id: String, name: String, email: String, role: UserRole) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let idCandidate = try container.decodeIfPresent(String.self, forKey: .id), !idCandidate.isEmpty {
            self.id = idCandidate
        } else if let idCandidate = try container.decodeIfPresent(String.self, forKey: ._id), !idCandidate.isEmpty {
            self.id = idCandidate
        } else {
            self.id = ""
        }
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        self.role = try container.decodeIfPresent(UserRole.self, forKey: .role) ?? .student
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
        try container.encode(role, forKey: .role)
    }

    static func extractUserId(from token: String?) -> String? {
        guard let token else { return nil }
        let trimmed = token.replacingOccurrences(of: "Bearer ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.components(separatedBy: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        guard let data = Data(base64Encoded: base64),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        return (json["id"] as? String) ?? (json["_id"] as? String) ?? (json["userId"] as? String)
    }
}

struct LoginResponse: Codable {
    let token: String
    let user: UserProfile
}

struct RegistrationRequest: Encodable {
    let name: String
    let email: String
    let password: String
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct BackendErrorResponse: Decodable {
    let error: String?
    let message: String?
}

enum APIError: LocalizedError, Equatable {
    case invalidResponse
    case unauthorized
    case server(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The server sent an unreadable response."
        case .unauthorized:
            "Your session has expired. Please sign in again."
        case .server(let message), .transport(let message):
            message
        }
    }
}

@MainActor
final class APIClient {
    static let shared = APIClient()

    func login(email: String, password: String, role: UserRole) async throws -> LoginResponse {
        let endpoint = role == .admin ? "auth/admin/login" : "auth/login"
        return try await send(
            path: endpoint,
            method: "POST",
            body: LoginRequest(email: email, password: password),
            token: nil
        )
    }

    func registerStudent(name: String, email: String, password: String) async throws {
        struct RegistrationResponse: Decodable {}
        _ = try await send(
            path: "auth/register",
            method: "POST",
            body: RegistrationRequest(name: name, email: email, password: password),
            token: nil
        ) as RegistrationResponse
    }

    func profile(token: String) async throws -> UserProfile {
        try await send(path: "auth/profile", method: "GET", body: Optional<String>.none, token: token)
    }

    func studentModules(token: String) async throws -> [LearningModule] {
        var baseModules: [LearningModule] = []
        if let response: ModulesResponse = try? await send(
            path: "student/modules",
            method: "GET",
            body: Optional<String>.none,
            token: token
        ) {
            baseModules = response.modules
        }

        let custom = ModuleStore.shared.customModules
        var merged = baseModules
        let existingIDs = Set(baseModules.map(\.id))
        for mod in custom where !existingIDs.contains(mod.id) {
            merged.append(mod)
        }
        return merged.sortedSerialWise()
    }

    func moduleQuiz(id: String, token: String) async throws -> ModuleQuizResponse {
        if let customQuestions = ModuleStore.shared.questionsFor(moduleID: id), !customQuestions.isEmpty {
            return ModuleQuizResponse(questions: customQuestions)
        }

        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw APIError.unauthorized
        }

        var request = URLRequest(url: AppConfiguration.apiBaseURL.appending(path: "student/modules/\(id)"))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if trimmed.lowercased().hasPrefix("bearer ") {
            request.setValue(trimmed, forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(response: response, data: data)
            return ModuleQuizResponse.parse(from: data)
        } catch {
            if let customQuestions = ModuleStore.shared.questionsFor(moduleID: id) {
                return ModuleQuizResponse(questions: customQuestions)
            }
            throw error
        }
    }

    func submitAttempt(_ attempt: AttemptSubmission, token: String) async throws {
        struct AttemptResponse: Decodable {}
        let _: AttemptResponse = try await send(
            path: "student/attempts",
            method: "POST",
            body: attempt,
            token: token
        )
    }

    func studentAnalytics(token: String) async throws -> StudentAnalytics {
        try await send(
            path: "student/analytics",
            method: "GET",
            body: Optional<String>.none,
            token: token
        )
    }

    func studentLeaderboard(token: String) async throws -> [LeaderboardEntry] {
        try await send(
            path: "student/leaderboard",
            method: "GET",
            body: Optional<String>.none,
            token: token
        )
    }

    func mistakeVault(token: String) async throws -> [MistakeVaultItem] {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw APIError.unauthorized
        }

        var request = URLRequest(url: AppConfiguration.apiBaseURL.appending(path: "student/mistake-vault"))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if trimmed.lowercased().hasPrefix("bearer ") {
            request.setValue(trimmed, forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        return MistakeVaultItem.parseList(from: data)
    }

    func uploadDocument(fileURL: URL, token: String) async throws {
        let boundary = UUID().uuidString
        var request = URLRequest(url: AppConfiguration.apiBaseURL.appending(path: "admin/documents/upload"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let (_, response) = try await URLSession.shared.upload(for: request, from: body)
        try validate(response: response, data: nil)
    }

    func facultyStudents(token: String, scope: String? = nil) async throws -> [FacultyStudent] {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw APIError.unauthorized
        }

        var queryItems: [URLQueryItem]? = nil
        if let scope, !scope.isEmpty {
            queryItems = [URLQueryItem(name: "scope", value: scope)]
        }

        let response: FacultyStudentsResponse = try await send(
            path: "faculty/students",
            method: "GET",
            body: Optional<String>.none,
            token: token,
            queryItems: queryItems
        )
        return response.students
    }

    func allFacultyStudents(token: String) async throws -> [FacultyStudent] {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw APIError.unauthorized
        }

        if let withAll: FacultyStudentsResponse = try? await send(
            path: "faculty/students",
            method: "GET",
            body: Optional<String>.none,
            token: token,
            queryItems: [URLQueryItem(name: "all", value: "true")]
        ), !withAll.students.isEmpty {
            return withAll.students
        }

        if let altAll: FacultyStudentsResponse = try? await send(
            path: "faculty/all-students",
            method: "GET",
            body: Optional<String>.none,
            token: token
        ), !altAll.students.isEmpty {
            return altAll.students
        }

        return try await facultyStudents(token: token)
    }

    func createFacultyTest(
        title: String,
        moduleID: String,
        durationMinutes: Int,
        questions: [TestQuestion],
        token: String
    ) async throws -> FacultyTest {
        struct CreateTestRequest: Encodable {
            let title: String
            let moduleId: String
            let durationMinutes: Int
            let questions: [TestQuestion]
        }

        let body = CreateTestRequest(
            title: title,
            moduleId: moduleID,
            durationMinutes: durationMinutes,
            questions: questions
        )

        return try await send(
            path: "faculty/tests",
            method: "POST",
            body: body,
            token: token
        )
    }

    func fetchFacultyTests(token: String) async throws -> [FacultyTest] {
        struct TestsResponse: Decodable {
            let tests: [FacultyTest]
            enum CodingKeys: String, CodingKey {
                case tests, data
            }
            init(from decoder: Decoder) throws {
                if let direct = try? decoder.singleValueContainer().decode([FacultyTest].self) {
                    self.tests = direct
                    return
                }
                let container = try? decoder.container(keyedBy: CodingKeys.self)
                self.tests = (try? container?.decodeIfPresent([FacultyTest].self, forKey: .tests))
                    ?? (try? container?.decodeIfPresent([FacultyTest].self, forKey: .data))
                    ?? []
            }
        }

        let response: TestsResponse = try await send(
            path: "faculty/tests",
            method: "GET",
            body: Optional<String>.none,
            token: token
        )
        return response.tests
    }

    func fetchStudentTests(token: String) async throws -> [FacultyTest] {
        if let response: [FacultyTest] = try? await send(
            path: "student/tests",
            method: "GET",
            body: Optional<String>.none,
            token: token
        ) {
            return response
        }

        return (try? await fetchFacultyTests(token: token)) ?? []
    }

    func fetchAdminQuestionsNeedsReview(token: String) async throws -> [QuizQuestion] {
        struct ReviewResponse: Decodable {
            let questions: [QuizQuestion]
            enum CodingKeys: String, CodingKey {
                case questions, data
            }
            init(from decoder: Decoder) throws {
                if let direct = try? decoder.singleValueContainer().decode([QuizQuestion].self) {
                    self.questions = direct
                    return
                }
                let container = try? decoder.container(keyedBy: CodingKeys.self)
                self.questions = (try? container?.decodeIfPresent([QuizQuestion].self, forKey: .questions))
                    ?? (try? container?.decodeIfPresent([QuizQuestion].self, forKey: .data))
                    ?? []
            }
        }

        let response: ReviewResponse = try await send(
            path: "admin/questions/needs-review",
            method: "GET",
            body: Optional<String>.none,
            token: token
        )
        return response.questions
    }

    func publishAdminModule(title: String, questions: [QuizQuestion], token: String) async throws {
        struct PublishModuleRequest: Encodable {
            let title: String
            let questions: [QuizQuestion]
        }
        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await send(
            path: "admin/modules",
            method: "POST",
            body: PublishModuleRequest(title: title, questions: questions),
            token: token
        )
    }

    private func send<Request: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Request?,
        token: String?,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> Response {
        var url = AppConfiguration.apiBaseURL.appending(path: path)
        if let queryItems, !queryItems.isEmpty {
            url.append(queryItems: queryItems)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                if trimmed.lowercased().hasPrefix("bearer ") {
                    request.setValue(trimmed, forHTTPHeaderField: "Authorization")
                } else {
                    request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
                }
            }
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(response: response, data: data)
            return try JSONDecoder().decode(Response.self, from: data)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }

    private func validate(response: URLResponse, data: Data?) throws {
        guard let response = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(response.statusCode) else {
            if let data,
               let backendError = try? JSONDecoder().decode(BackendErrorResponse.self, from: data),
               let message = backendError.error ?? backendError.message,
               !message.isEmpty {
                if response.statusCode == 401 || response.statusCode == 403 || message.localizedCaseInsensitiveContains("token") {
                    throw APIError.unauthorized
                }
                throw APIError.server(message)
            }

            if response.statusCode == 401 || response.statusCode == 403 {
                throw APIError.unauthorized
            }

            throw APIError.server("The request failed with status \(response.statusCode).")
        }
    }
}

enum KeychainStore {
    private static let service = "com.aptirush.app"
    private static let account = "session-token"

    static func save(token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
        var insert = query
        insert[kSecValueData as String] = data
        let status = SecItemAdd(insert as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw APIError.transport("Unable to securely save your session.")
        }
    }

    static func token() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
@Observable
final class SessionStore {
    private(set) var user: UserProfile?
    private(set) var token: String?
    private(set) var isRestoring = true
    var errorMessage: String?

    var isAuthenticated: Bool {
        user != nil && token != nil
    }

    func restoreSession() async {
        defer { isRestoring = false }

        guard let token = KeychainStore.token() else {
            return
        }

        do {
            var profile = try await APIClient.shared.profile(token: token)
            if profile.id.isEmpty, let jwtId = UserProfile.extractUserId(from: token) {
                profile = UserProfile(id: jwtId, name: profile.name, email: profile.email, role: profile.role)
            }
            self.token = token
            user = profile
        } catch {
            signOut()
        }
    }

    func signIn(email: String, password: String, role: UserRole) async -> Bool {
        errorMessage = nil

        do {
            let response = try await APIClient.shared.login(email: email, password: password, role: role)
            try KeychainStore.save(token: response.token)
            self.token = response.token
            var user = response.user
            if user.id.isEmpty, let jwtId = UserProfile.extractUserId(from: response.token) {
                user = UserProfile(id: jwtId, name: user.name, email: user.email, role: user.role)
            }
            self.user = user
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func registerStudent(name: String, email: String, password: String) async -> Bool {
        errorMessage = nil

        do {
            try await APIClient.shared.registerStudent(name: name, email: email, password: password)
            return await signIn(email: email, password: password, role: .student)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func signOut() {
        KeychainStore.deleteToken()
        token = nil
        user = nil
        errorMessage = nil
    }
}

// MARK: - Crisp Modern Aesthetic Design System

enum AestheticTheme {
    // Single signature vibrant accent: Pure Electric Rush Orange
    static let accent = Color(red: 1.0, green: 0.38, blue: 0.0) // #FF6100
    
    // Status colors: solid, crisp, unblended
    static let success = Color(red: 0.13, green: 0.77, blue: 0.45) // #22C55E
    static let warning = Color(red: 0.96, green: 0.62, blue: 0.04) // #F59E0B
    static let danger = Color(red: 0.94, green: 0.27, blue: 0.27)  // #EF4444
    static let info = Color(red: 0.23, green: 0.51, blue: 0.96)    // #3B82F6
    static let darkCard = Color(red: 0.08, green: 0.09, blue: 0.12) // #14171F
}

// Compatibility mappings pointing to pure, unblended solid colors:
enum LuxuryTheme {
    static let primarySunset = [AestheticTheme.accent, AestheticTheme.accent]
    static let auroraPurple = [Color.purple, Color.purple]
    static let oceanCyan = [Color.blue, Color.blue]
    static let emeraldSuccess = [AestheticTheme.success, AestheticTheme.success]
    static let amberGold = [AestheticTheme.warning, AestheticTheme.warning]
}

struct LuxuryGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 18
    var strokeOpacity: CGFloat = 0.08

    func body(content: Content) -> some View {
        content
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(strokeOpacity), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

extension View {
    func luxuryGlass(cornerRadius: CGFloat = 18, strokeOpacity: CGFloat = 0.08) -> some View {
        modifier(LuxuryGlassModifier(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity))
    }

    func aestheticCard(cornerRadius: CGFloat = 18, strokeOpacity: CGFloat = 0.08) -> some View {
        modifier(LuxuryGlassModifier(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity))
    }
}

// Clean unified backdrop - eliminates muddy color bleed
struct AmbientGlowCanvas: View {
    var primaryColor: Color = Color.clear
    var secondaryColor: Color = Color.clear

    var body: some View {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
    }
}
