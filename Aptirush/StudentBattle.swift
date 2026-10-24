import Foundation
import Observation
import SwiftUI
import UIKit

// MARK: - Models

struct BattleQuestion: Identifiable, Hashable {
    let id: String
    let questionText: String
    let options: [QuizOption]
    let correctAnswer: String?
    let type: String?

    var isTITA: Bool {
        if let type, type.uppercased().contains("TITA") {
            return true
        }
        return options.isEmpty || options.count < 2
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BattleQuestion, rhs: BattleQuestion) -> Bool {
        lhs.id == rhs.id
    }

    static func parse(from dict: [String: Any]) -> BattleQuestion? {
        let id = (dict["id"] as? String) ?? (dict["_id"] as? String) ?? UUID().uuidString
        let text = (dict["questionText"] as? String)
            ?? (dict["text"] as? String)
            ?? (dict["question"] as? String)
            ?? "Aptitude Duel Question"
        let correct = (dict["correctAnswer"] as? String) ?? (dict["correct"] as? String)
        let type = dict["type"] as? String

        // 1v1 Arena only permits Multiple Choice (MCQ) questions - Disallow TITA / Text inputs:
        if let typeStr = type?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
           typeStr.contains("TITA") || typeStr == "TEXT" || typeStr == "INPUT" {
            return nil
        }

        var parsedOptions: [QuizOption] = []
        if let optDict = dict["options"] as? [String: Any] {
            let sortedKeys = optDict.keys.sorted()
            for key in sortedKeys {
                let optText = "\(optDict[key] ?? "")"
                parsedOptions.append(QuizOption(id: key, text: optText))
            }
        } else if let optArray = dict["options"] as? [String] {
            for (idx, optText) in optArray.enumerated() {
                let key = String(UnicodeScalar(65 + idx)!)
                parsedOptions.append(QuizOption(id: key, text: optText))
            }
        } else if let optObjArray = dict["options"] as? [[String: Any]] {
            for (idx, optObj) in optObjArray.enumerated() {
                let defaultKey = String(UnicodeScalar(65 + idx)!)
                let key = (optObj["id"] as? String) ?? (optObj["key"] as? String) ?? (optObj["optionKey"] as? String) ?? defaultKey
                let text = (optObj["text"] as? String) ?? (optObj["optionText"] as? String) ?? (optObj["label"] as? String) ?? "\(optObj)"
                parsedOptions.append(QuizOption(id: key, text: text))
            }
        }

        // In 1v1 Arena, ensure there are at least 2 selectable options (never TITA):
        guard parsedOptions.count >= 2 else {
            return nil
        }

        return BattleQuestion(
            id: id,
            questionText: text,
            options: parsedOptions,
            correctAnswer: correct,
            type: "MCQ"
        )
    }
}

let defaultMCQBattleQuestions: [BattleQuestion] = [
    BattleQuestion(
        id: "mcq_1",
        questionText: "A train traveling at 72 km/h crosses a 260 m long platform in 23 seconds. What is the length of the train?",
        options: [
            QuizOption(id: "A", text: "200 m"),
            QuizOption(id: "B", text: "220 m"),
            QuizOption(id: "C", text: "240 m"),
            QuizOption(id: "D", text: "180 m")
        ],
        correctAnswer: "A",
        type: "MCQ"
    ),
    BattleQuestion(
        id: "mcq_2",
        questionText: "If 15 men can complete a project in 12 days working 8 hours a day, how many days will 18 men take working 6 hours a day?",
        options: [
            QuizOption(id: "A", text: "10 days"),
            QuizOption(id: "B", text: "13.3 days"),
            QuizOption(id: "C", text: "15 days"),
            QuizOption(id: "D", text: "12 days")
        ],
        correctAnswer: "B",
        type: "MCQ"
    ),
    BattleQuestion(
        id: "mcq_3",
        questionText: "The ratio of present ages of A and B is 3:5. After 6 years, the ratio becomes 2:3. What is B's present age?",
        options: [
            QuizOption(id: "A", text: "25 years"),
            QuizOption(id: "B", text: "30 years"),
            QuizOption(id: "C", text: "35 years"),
            QuizOption(id: "D", text: "20 years")
        ],
        correctAnswer: "B",
        type: "MCQ"
    ),
    BattleQuestion(
        id: "mcq_4",
        questionText: "A shopkeeper marks an article 40% above cost price and allows a 20% discount. What is the net profit percentage?",
        options: [
            QuizOption(id: "A", text: "12%"),
            QuizOption(id: "B", text: "15%"),
            QuizOption(id: "C", text: "20%"),
            QuizOption(id: "D", text: "8%")
        ],
        correctAnswer: "A",
        type: "MCQ"
    ),
    BattleQuestion(
        id: "mcq_5",
        questionText: "Pointing to a photograph, a woman says: 'He is the only son of my father's father.' How is the man related to the woman?",
        options: [
            QuizOption(id: "A", text: "Father"),
            QuizOption(id: "B", text: "Uncle"),
            QuizOption(id: "C", text: "Brother"),
            QuizOption(id: "D", text: "Grandfather")
        ],
        correctAnswer: "A",
        type: "MCQ"
    ),
    BattleQuestion(
        id: "mcq_6",
        questionText: "Find the next number in the series: 4, 9, 25, 49, 121, ?",
        options: [
            QuizOption(id: "A", text: "144"),
            QuizOption(id: "B", text: "169"),
            QuizOption(id: "C", text: "196"),
            QuizOption(id: "D", text: "225")
        ],
        correctAnswer: "B",
        type: "MCQ"
    ),
    BattleQuestion(
        id: "mcq_7",
        questionText: "Pipe A can fill a tank in 6 hours and Pipe B can empty it in 8 hours. If both are opened together, how long will it take to fill the tank?",
        options: [
            QuizOption(id: "A", text: "24 hours"),
            QuizOption(id: "B", text: "14 hours"),
            QuizOption(id: "C", text: "18 hours"),
            QuizOption(id: "D", text: "12 hours")
        ],
        correctAnswer: "A",
        type: "MCQ"
    )
]

struct BattleData: Identifiable, Hashable {
    var id: String { battleId }
    let battleId: String
    let p1Id: String
    let p2Id: String
    let questions: [BattleQuestion]

    func hash(into hasher: inout Hasher) {
        hasher.combine(battleId)
    }

    static func == (lhs: BattleData, rhs: BattleData) -> Bool {
        lhs.battleId == rhs.battleId
    }

    static func parse(from dict: [String: Any]) -> BattleData? {
        let bId = (dict["battleId"] as? String)
            ?? (dict["id"] as? String)
            ?? (dict["_id"] as? String)
            ?? (dict["roomId"] as? String)
        guard let bId else { return nil }

        let p1 = (dict["p1Id"] as? String) ?? (dict["player1Id"] as? String) ?? (dict["p1"] as? String) ?? ""
        let p2 = (dict["p2Id"] as? String) ?? (dict["player2Id"] as? String) ?? (dict["p2"] as? String) ?? ""

        var qs: [BattleQuestion] = []
        if let qArray = (dict["questions"] as? [[String: Any]]) ?? (dict["battleQuestions"] as? [[String: Any]]) {
            for qDict in qArray {
                if let q = BattleQuestion.parse(from: qDict), !q.isTITA {
                    qs.append(q)
                }
            }
        }

        // Ensure 1v1 duel always has at least 5 valid MCQ questions (never TITA):
        if qs.count < 5 {
            let needed = 5 - qs.count
            let fallbacks = defaultMCQBattleQuestions.filter { fb in !qs.contains(where: { $0.id == fb.id }) }
            qs.append(contentsOf: fallbacks.prefix(needed))
        }

        return BattleData(
            battleId: bId,
            p1Id: p1,
            p2Id: p2,
            questions: qs
        )
    }
}

struct BattleSyncPayload {
    let currentQIndex: Int
    let p1Score: Int
    let p2Score: Int
    let p1Id: String?
    let p2Id: String?
    let questionClaimed: Bool
    let isLocked: Bool
    let claimedBy: String?
}

struct BattleResolvedPayload {
    let p1Score: Int
    let p2Score: Int
    let correctAnswer: String?
    let claimedBy: String?
}

struct BattleNextQPayload {
    let currentQIndex: Int
    let p1Score: Int
    let p2Score: Int
}

struct BattleCompletedPayload {
    let p1Score: Int
    let p2Score: Int
    let winnerId: String?
    let isDraw: Bool
    let eloChanges: [String: Int]
}

enum BattleRoundStatus: Equatable {
    case idle
    case claimedByMe
    case claimedByOpponent
    case myAnswerWrong
    case opponentMissed
    case bothMissed

    var title: String {
        switch self {
        case .idle:
            return "First to choose the correct answer claims the point!"
        case .claimedByMe:
            return "⚡ Point Secured! You answered correctly first!"
        case .claimedByOpponent:
            return "🔒 Too slow! Opponent marked the answer first!"
        case .myAnswerWrong:
            return "❌ Incorrect! You are locked out of this question."
        case .opponentMissed:
            return "🔥 Opponent missed! Pick the correct answer to steal!"
        case .bothMissed:
            return "Both players missed! Advancing..."
        }
    }

    var color: Color {
        switch self {
        case .idle:
            return .secondary
        case .claimedByMe:
            return .green
        case .claimedByOpponent:
            return .red
        case .myAnswerWrong:
            return .orange
        case .opponentMissed:
            return .purple
        case .bothMissed:
            return .secondary
        }
    }

    var icon: String {
        switch self {
        case .idle:
            return "bolt.fill"
        case .claimedByMe:
            return "checkmark.circle.fill"
        case .claimedByOpponent:
            return "xmark.circle.fill"
        case .myAnswerWrong:
            return "exclamationmark.triangle.fill"
        case .opponentMissed:
            return "sparkles"
        case .bothMissed:
            return "minus.circle.fill"
        }
    }
}

enum EloTier: String, CaseIterable {
    case initiate = "Initiate"
    case bronze = "Bronze Crest"
    case silver = "Silver Vanguard"
    case gold = "Gold Gladiator"
    case diamond = "Diamond Contender"
    case master = "Master"
    case apex = "Apex Master"

    static func tier(for elo: Int) -> EloTier {
        switch elo {
        case ..<1100: return .initiate
        case 1100..<1400: return .bronze
        case 1400..<1700: return .silver
        case 1700..<2000: return .gold
        case 2000..<2400: return .diamond
        case 2400..<2800: return .master
        default: return .apex
        }
    }

    var icon: String {
        switch self {
        case .initiate: return "shield"
        case .bronze: return "shield.lefthalf.filled"
        case .silver: return "shield.fill"
        case .gold: return "crown"
        case .diamond: return "rhombus.fill"
        case .master: return "crown.fill"
        case .apex: return "flame.fill"
        }
    }

    var color: Color {
        switch self {
        case .initiate: return .gray
        case .bronze: return .brown
        case .silver: return .cyan
        case .gold: return .yellow
        case .diamond: return .blue
        case .master: return .purple
        case .apex: return .orange
        }
    }
}

// MARK: - Native Socket.IO Client (Singleton)

@MainActor
final class BattleSocketClient {
    static let shared = BattleSocketClient()

    private var webSocket: URLSessionWebSocketTask?
    private var pingTimer: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var isConnecting = false
    private(set) var isConnected = false
    private var isReading = false
    private var pendingEmits: [(event: String, payload: [String: Any])] = []

    var activeBattleId: String? = nil
    var currentUserId: String? = nil

    var onConnect: (() -> Void)?
    var onMatchFound: ((BattleData) -> Void)?
    var onPrivateRoomCreated: ((String) -> Void)?
    var onRoomError: ((String) -> Void)?
    var onBattleSync: ((BattleSyncPayload) -> Void)?
    var onQuestionResolved: ((BattleResolvedPayload) -> Void)?
    var onAnswerIncorrect: (() -> Void)?
    var onOpponentMissed: (() -> Void)?
    var onNextQuestion: ((BattleNextQPayload) -> Void)?
    var onBattleCompleted: ((BattleCompletedPayload) -> Void)?
    var onDisconnect: (() -> Void)?

    static func parseInt(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String, let i = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) { return i }
        return nil
    }

    func connect() {
        if isConnected && webSocket != nil {
            flushPendingEmits()
            return
        }

        guard !isConnecting else { return }
        isConnecting = true

        cleanupSocketOnly()

        Task { [weak self] in
            await self?.performHandshakeAndConnect()
        }
    }

    private func performHandshakeAndConnect() async {
        do {
            guard let handshakeURL = URL(string: "https://aptirush.onrender.com/socket.io/?EIO=4&transport=polling") else {
                isConnecting = false
                return
            }

            var request = URLRequest(url: handshakeURL)
            request.setValue("https://aptirush.onrender.com", forHTTPHeaderField: "Origin")
            request.setValue("https://aptirush.onrender.com", forHTTPHeaderField: "Referer")
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 8

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let text = String(data: data, encoding: .utf8), text.hasPrefix("0") else {
                throw NSError(domain: "BattleSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid handshake response"])
            }

            let jsonString = String(text.dropFirst())
            guard let jsonData = jsonString.data(using: .utf8),
                  let json = (try? JSONSerialization.jsonObject(with: jsonData)) as? [String: Any],
                  let sid = json["sid"] as? String else {
                throw NSError(domain: "BattleSocket", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing session ID in handshake"])
            }

            var cookieHeader: String? = nil
            if let httpRes = response as? HTTPURLResponse, let cookie = httpRes.allHeaderFields["Set-Cookie"] as? String {
                cookieHeader = cookie
            }

            guard var wsComponents = URLComponents(string: "wss://aptirush.onrender.com/socket.io/") else {
                isConnecting = false
                return
            }
            wsComponents.queryItems = [
                URLQueryItem(name: "EIO", value: "4"),
                URLQueryItem(name: "transport", value: "websocket"),
                URLQueryItem(name: "sid", value: sid)
            ]
            guard let wsURL = wsComponents.url else {
                isConnecting = false
                return
            }

            let config = URLSessionConfiguration.default
            var additionalHeaders: [String: String] = [
                "Origin": "https://aptirush.onrender.com",
                "Referer": "https://aptirush.onrender.com",
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"
            ]
            if let cookieHeader {
                additionalHeaders["Cookie"] = cookieHeader
            }
            config.httpAdditionalHeaders = additionalHeaders

            cleanupSocketOnly()

            let session = URLSession(configuration: config)
            let ws = session.webSocketTask(with: wsURL)
            self.webSocket = ws
            ws.resume()

            self.startReading()
            self.startPingTimer()

            ws.send(.string("2probe")) { _ in }

        } catch {
            self.isConnecting = false
            self.cleanupSocketOnly()
            self.onDisconnect?()
            if self.activeBattleId != nil || !self.pendingEmits.isEmpty {
                self.scheduleReconnect()
            }
        }
    }

    private func cleanupSocketOnly() {
        pingTimer?.cancel()
        pingTimer = nil
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        isConnected = false
        isReading = false
    }

    func disconnect() {
        isConnecting = false
        cleanupSocketOnly()
        onDisconnect?()

        // Auto-reconnect if battle or pending action in progress
        if activeBattleId != nil || !pendingEmits.isEmpty {
            scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard let self, !self.isConnected, !self.isConnecting, (self.activeBattleId != nil || !self.pendingEmits.isEmpty) else { return }
            self.connect()
        }
    }

    func emit(event: String, payload: [String: Any]) {
        if !isConnected || webSocket == nil {
            pendingEmits.append((event, payload))
            connect()
            return
        }
        sendPacket(event: event, payload: payload)
    }

    private func sendPacket(event: String, payload: [String: Any]) {
        guard let ws = webSocket else { return }
        do {
            let data = try JSONSerialization.data(withJSONObject: [event, payload])
            if let str = String(data: data, encoding: .utf8) {
                let packet = "42\(str)"
                ws.send(.string(packet)) { _ in }
            }
        } catch {
            print("Failed to serialize event packet:", error)
        }
    }

    private func flushPendingEmits() {
        let items = pendingEmits
        pendingEmits.removeAll()
        for item in items {
            sendPacket(event: item.event, payload: item.payload)
        }
    }

    private func startPingTimer() {
        pingTimer?.cancel()
        pingTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard let self, self.isConnected, let ws = self.webSocket else { break }
                try? await ws.send(.string("2"))
            }
        }
    }

    private func startReading() {
        guard !isReading, let ws = webSocket else { return }
        isReading = true

        Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let ws = self.webSocket else { break }
                do {
                    let message = try await ws.receive()
                    switch message {
                    case .string(let text):
                        self.handlePacket(text)
                    case .data:
                        break
                    @unknown default:
                        break
                    }
                } catch {
                    self.disconnect()
                    break
                }
            }
        }
    }

    private func handlePacket(_ text: String) {
        if text == "3probe" {
            webSocket?.send(.string("5")) { _ in }
            webSocket?.send(.string("40")) { _ in }
        } else if text.hasPrefix("0") {
            // Engine.IO handshake response -> acknowledge Socket.IO
            webSocket?.send(.string("40")) { _ in }
        } else if text.hasPrefix("40") {
            isConnected = true
            isConnecting = false
            reconnectTask?.cancel()
            reconnectTask = nil
            onConnect?()
            // Auto-rejoin active battle on reconnect
            if let bId = activeBattleId, let uId = currentUserId {
                sendPacket(event: "join_battle", payload: [
                    "battleId": bId,
                    "userId": uId
                ])
            }
            flushPendingEmits()
        } else if text.hasPrefix("2") {
            webSocket?.send(.string("3")) { _ in }
        } else if text.hasPrefix("42") {
            var str = text.dropFirst(2)
            while let first = str.first, first.isNumber {
                str = str.dropFirst()
            }
            guard let data = str.data(using: .utf8),
                  let jsonArray = (try? JSONSerialization.jsonObject(with: data)) as? [Any],
                  let eventName = jsonArray.first as? String else {
                return
            }
            var payload: [String: Any] = [:]
            if jsonArray.count > 1 {
                if let dict = jsonArray[1] as? [String: Any] {
                    payload = dict
                } else if let strVal = jsonArray[1] as? String {
                    payload = ["roomId": strVal, "message": strVal, "error": strVal, "value": strVal]
                }
            }
            dispatch(event: eventName, payload: payload)
        }
    }

    private func dispatch(event: String, payload: [String: Any]) {
        switch event {
        case "match_found":
            if let battleData = BattleData.parse(from: payload) {
                onMatchFound?(battleData)
            }
        case "private_room_created":
            let roomId = (payload["roomId"] as? String)
                ?? (payload["roomCode"] as? String)
                ?? (payload["code"] as? String)
                ?? (payload["value"] as? String)
            if let roomId {
                onPrivateRoomCreated?(roomId)
            }
        case "room_error":
            let msg = (payload["message"] as? String)
                ?? (payload["error"] as? String)
                ?? (payload["value"] as? String)
                ?? "Unable to join chamber. Please check the PIN and try again."
            onRoomError?(msg)
        case "battle_sync":
            let currentQ = Self.parseInt(payload["currentQIndex"]) ?? 0
            let p1 = Self.parseInt(payload["p1Score"]) ?? 0
            let p2 = Self.parseInt(payload["p2Score"]) ?? 0
            let p1Id = payload["p1Id"] as? String
            let p2Id = payload["p2Id"] as? String
            let claimed = (payload["questionClaimed"] as? Bool) ?? false
            let locked = (payload["isLocked"] as? Bool) ?? false
            let claimedBy = payload["claimedBy"] as? String
            onBattleSync?(BattleSyncPayload(
                currentQIndex: currentQ,
                p1Score: p1,
                p2Score: p2,
                p1Id: p1Id,
                p2Id: p2Id,
                questionClaimed: claimed,
                isLocked: locked,
                claimedBy: claimedBy
            ))
        case "question_resolved":
            let p1 = Self.parseInt(payload["p1Score"]) ?? 0
            let p2 = Self.parseInt(payload["p2Score"]) ?? 0
            let correct = (payload["correctAnswer"] as? String) ?? (payload["correct"] as? String)
            let claimedBy = (payload["claimedBy"] as? String) ?? (payload["winnerId"] as? String)
            onQuestionResolved?(BattleResolvedPayload(
                p1Score: p1,
                p2Score: p2,
                correctAnswer: correct,
                claimedBy: claimedBy
            ))
        case "answer_incorrect":
            onAnswerIncorrect?()
        case "opponent_missed":
            onOpponentMissed?()
        case "next_question":
            let currentQ = Self.parseInt(payload["currentQIndex"])
                ?? Self.parseInt(payload["questionIndex"])
                ?? Self.parseInt(payload["nextQuestionIndex"])
                ?? Self.parseInt(payload["index"])
                ?? 0
            let p1 = Self.parseInt(payload["p1Score"]) ?? 0
            let p2 = Self.parseInt(payload["p2Score"]) ?? 0
            onNextQuestion?(BattleNextQPayload(currentQIndex: currentQ, p1Score: p1, p2Score: p2))
        case "battle_completed":
            let p1 = Self.parseInt(payload["p1Score"]) ?? 0
            let p2 = Self.parseInt(payload["p2Score"]) ?? 0
            let winner = payload["winnerId"] as? String
            let isDraw = (payload["isDraw"] as? Bool) ?? (p1 == p2)
            var eloMap: [String: Int] = [:]
            if let changes = payload["eloChanges"] as? [String: Any] {
                for (k, v) in changes {
                    if let parsed = Self.parseInt(v) {
                        eloMap[k] = parsed
                    }
                }
            }
            onBattleCompleted?(BattleCompletedPayload(
                p1Score: p1,
                p2Score: p2,
                winnerId: winner,
                isDraw: isDraw,
                eloChanges: eloMap
            ))
        default:
            break
        }
    }
}

// MARK: - Battle Lobby ViewModel

@MainActor
@Observable
final class BattleLobbyViewModel {
    enum MatchmakingMode: String, CaseIterable, Identifiable {
        case random = "Random Match"
        case chamber = "Private Chamber"
        case bot = "Practice Duel (AI)"

        var id: String { rawValue }
    }

    var mode: MatchmakingMode = .random
    var isSearching = false
    var searchSeconds = 0
    var createdRoomId: String? = nil
    var joinRoomCode = ""
    var errorMessage: String? = nil
    var activeBattle: BattleData? = nil
    var isPractice = false

    private let socket = BattleSocketClient.shared
    private var searchTimer: Task<Void, Never>?

    init() {
        bindSocketHandlers()
    }

    func bindSocketHandlers() {
        socket.onPrivateRoomCreated = { [weak self] roomId in
            self?.createdRoomId = roomId
            self?.isSearching = false
            self?.stopSearchTimer()
        }
        socket.onRoomError = { [weak self] message in
            self?.errorMessage = message
            self?.isSearching = false
            self?.stopSearchTimer()
        }
        socket.onMatchFound = { [weak self] battleData in
            self?.isSearching = false
            self?.stopSearchTimer()
            self?.createdRoomId = nil
            self?.activeBattle = battleData
        }
        socket.onDisconnect = { [weak self] in
            guard let self else { return }
            if self.isSearching && self.createdRoomId == nil {
                self.isSearching = false
                self.stopSearchTimer()
                self.errorMessage = "Connection lost. Please tap to retry."
            }
        }
    }

    func setupSocket(userId: String) {
        bindSocketHandlers()
        socket.connect()
    }

    func startRandomQueue(userId: String) {
        guard !userId.isEmpty else {
            errorMessage = "Please sign in to battle."
            return
        }
        errorMessage = nil
        isSearching = true
        searchSeconds = 0
        isPractice = false
        startSearchTimer()

        bindSocketHandlers()
        socket.currentUserId = userId
        socket.connect()
        socket.emit(event: "join_queue", payload: ["userId": userId])
    }

    func cancelQueue() {
        stopSearchTimer()
        isSearching = false
        socket.emit(event: "leave_queue", payload: [:])
    }

    func createChamber(userId: String) {
        guard !userId.isEmpty else {
            errorMessage = "Please sign in to battle."
            return
        }
        errorMessage = nil
        createdRoomId = nil
        isSearching = true
        isPractice = false

        bindSocketHandlers()
        socket.currentUserId = userId
        socket.connect()
        socket.emit(event: "create_private_room", payload: ["userId": userId])

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard let self, self.isSearching, self.createdRoomId == nil, self.activeBattle == nil else { return }
            self.isSearching = false
            if self.errorMessage == nil {
                self.errorMessage = "Chamber creation timed out. Please try again."
            }
        }
    }

    func disbandChamber() {
        if let roomId = createdRoomId {
            socket.emit(event: "cancel_private_room", payload: ["roomId": roomId])
        }
        createdRoomId = nil
        isSearching = false
    }

    func joinChamber(userId: String) {
        let code = joinRoomCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else {
            errorMessage = "Please enter a valid 6-digit chamber PIN."
            return
        }
        guard !userId.isEmpty else {
            errorMessage = "Please sign in to battle."
            return
        }
        errorMessage = nil
        isSearching = true
        isPractice = false

        bindSocketHandlers()
        socket.currentUserId = userId
        socket.connect()
        socket.emit(event: "join_private_room", payload: [
            "userId": userId,
            "roomId": code,
            "roomCode": code,
            "code": code
        ])

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard let self, self.isSearching, self.activeBattle == nil else { return }
            self.isSearching = false
            if self.errorMessage == nil {
                self.errorMessage = "Chamber join timed out. Please verify the PIN."
            }
        }
    }

    func startPracticeMatch(userId: String, token: String?) async {
        guard !userId.isEmpty else {
            errorMessage = "Please sign in to practice."
            return
        }
        isSearching = true
        errorMessage = nil
        isPractice = true

        let activeToken = token ?? KeychainStore.token() ?? ""

        do {
            let modules = try await APIClient.shared.studentModules(token: activeToken)

            // Gather only non-TITA questions across available modules
            var candidateQuestions: [QuizQuestion] = []
            for mod in modules {
                if let quiz = try? await APIClient.shared.moduleQuiz(id: mod.id, token: activeToken) {
                    let nonTITA = quiz.questions.filter { q in
                        let isTITA = (q.type?.uppercased().contains("TITA") ?? false)
                            || q.isTextAnswer
                            || q.options.count < 2
                        return !isTITA
                    }
                    candidateQuestions.append(contentsOf: nonTITA)
                    if candidateQuestions.count >= 10 {
                        break
                    }
                }
            }

            let selected: [BattleQuestion]
            if !candidateQuestions.isEmpty {
                let chosen = Array(candidateQuestions.shuffled().prefix(5))
                selected = chosen.map { q in
                    BattleQuestion(
                        id: q.id,
                        questionText: q.text,
                        options: q.options,
                        correctAnswer: q.correctAnswer ?? q.options.first?.id,
                        type: "MCQ"
                    )
                }
            } else {
                selected = Array(defaultMCQBattleQuestions.shuffled().prefix(5))
            }

            let mockBattle = BattleData(
                battleId: "practice_\(UUID().uuidString.prefix(8))",
                p1Id: userId,
                p2Id: "aptibot-ai",
                questions: selected
            )

            isSearching = false
            activeBattle = mockBattle
        } catch {
            let mockBattle = BattleData(
                battleId: "practice_\(UUID().uuidString.prefix(8))",
                p1Id: userId,
                p2Id: "aptibot-ai",
                questions: Array(defaultMCQBattleQuestions.shuffled().prefix(5))
            )
            isSearching = false
            activeBattle = mockBattle
        }
    }

    private func startSearchTimer() {
        stopSearchTimer()
        searchTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self else { break }
                self.searchSeconds += 1
            }
        }
    }

    private func stopSearchTimer() {
        searchTimer?.cancel()
        searchTimer = nil
    }

    func resetBattleState() {
        activeBattle = nil
        isSearching = false
        createdRoomId = nil
        errorMessage = nil
        stopSearchTimer()
    }
}

// MARK: - Battle Room ViewModel

@MainActor
@Observable
final class BattleRoomViewModel {
    let battle: BattleData
    let currentUserId: String
    let opponentName: String
    let isPractice: Bool

    var currentQIndex = 0
    var p1Score = 0
    var p2Score = 0
    var selectedOptionKey: String? = nil
    var isLocked = false
    var roundStatus: BattleRoundStatus = .idle
    private var _isCompleted = false
    var winnerId: String? = nil
    var isDraw = false
    var eloChange: Int? = nil

    var isCompleted: Bool {
        get { _isCompleted || currentQIndex >= battle.questions.count }
        set { _isCompleted = newValue }
    }

    var myScore: Int {
        battle.p1Id == currentUserId ? p1Score : p2Score
    }

    var opponentScore: Int {
        battle.p1Id == currentUserId ? p2Score : p1Score
    }

    var currentQuestion: BattleQuestion? {
        guard currentQIndex < battle.questions.count else { return nil }
        return battle.questions[currentQIndex]
    }

    private let socket = BattleSocketClient.shared
    private var botTask: Task<Void, Never>?
    private var autoAdvanceTask: Task<Void, Never>?
    private var answerWatchdogTask: Task<Void, Never>?

    init(battle: BattleData, currentUserId: String, opponentName: String = "Opponent", isPractice: Bool = false) {
        self.battle = battle
        self.currentUserId = currentUserId
        self.opponentName = opponentName
        self.isPractice = isPractice
    }

    func start() {
        if isPractice {
            startPracticeMode()
        } else {
            socket.activeBattleId = battle.battleId
            socket.currentUserId = currentUserId
            setupLiveSocket()
        }
    }

    private func setupLiveSocket() {
        socket.onConnect = { [weak self] in
            guard let self else { return }
            self.socket.emit(event: "join_battle", payload: [
                "battleId": self.battle.battleId,
                "userId": self.currentUserId
            ])
        }

        socket.onBattleSync = { [weak self] sync in
            guard let self else { return }
            self.p1Score = sync.p1Score
            self.p2Score = sync.p2Score

            if sync.currentQIndex > self.currentQIndex {
                self.advanceToQuestion(index: sync.currentQIndex, p1: sync.p1Score, p2: sync.p2Score)
            } else if sync.currentQIndex == self.currentQIndex {
                if sync.questionClaimed {
                    if sync.claimedBy == self.currentUserId {
                        self.roundStatus = .claimedByMe
                    } else if sync.claimedBy != nil {
                        self.roundStatus = .claimedByOpponent
                    } else {
                        self.roundStatus = .bothMissed
                    }
                    self.isLocked = true
                    self.scheduleAutoAdvance(afterSeconds: 1.5)
                } else {
                    if !sync.isLocked {
                        self.isLocked = false
                        self.roundStatus = .idle
                        self.selectedOptionKey = nil
                    }
                }
            }
        }

        socket.onQuestionResolved = { [weak self] resolved in
            guard let self else { return }
            self.answerWatchdogTask?.cancel()
            self.answerWatchdogTask = nil

            self.p1Score = resolved.p1Score
            self.p2Score = resolved.p2Score
            self.isLocked = true
            if resolved.claimedBy == self.currentUserId {
                self.roundStatus = .claimedByMe
            } else if resolved.claimedBy != nil {
                self.roundStatus = .claimedByOpponent
            } else {
                self.roundStatus = .bothMissed
            }

            // Low-latency transition: server advances after 1.2s.
            // Client auto-advances at 1.8s if server next_question packet is delayed.
            self.scheduleAutoAdvance(afterSeconds: 1.8)
        }

        socket.onAnswerIncorrect = { [weak self] in
            guard let self else { return }
            self.isLocked = true
            self.roundStatus = .myAnswerWrong
            self.armSyncWatchdog(afterSeconds: 3.5)
        }

        socket.onOpponentMissed = { [weak self] in
            guard let self else { return }
            if self.roundStatus == .idle && !self.isLocked {
                self.roundStatus = .opponentMissed
            }
        }

        socket.onNextQuestion = { [weak self] next in
            guard let self else { return }
            self.autoAdvanceTask?.cancel()
            self.autoAdvanceTask = nil
            self.advanceToQuestion(index: next.currentQIndex, p1: next.p1Score, p2: next.p2Score)
        }

        socket.onBattleCompleted = { [weak self] completed in
            guard let self else { return }
            self.autoAdvanceTask?.cancel()
            self.autoAdvanceTask = nil
            self.answerWatchdogTask?.cancel()
            self.answerWatchdogTask = nil
            self.p1Score = completed.p1Score
            self.p2Score = completed.p2Score
            self.winnerId = completed.winnerId
            self.isDraw = completed.isDraw
            self.eloChange = completed.eloChanges[self.currentUserId]
            self.isCompleted = true
        }

        socket.emit(event: "join_battle", payload: [
            "battleId": battle.battleId,
            "userId": currentUserId
        ])
    }

    private func armSyncWatchdog(afterSeconds: Double) {
        answerWatchdogTask?.cancel()
        answerWatchdogTask = Task { [weak self] in
            let nanos = UInt64(afterSeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard let self, !Task.isCancelled, !self.isCompleted else { return }

            self.socket.emit(event: "join_battle", payload: [
                "battleId": self.battle.battleId,
                "userId": self.currentUserId
            ])

            // If still locked out after another 2.5s and round not idle, advance safely
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled, !self.isCompleted else { return }
            if self.isLocked && self.roundStatus != .idle {
                let nextIndex = self.currentQIndex + 1
                self.advanceToQuestion(index: nextIndex, p1: self.p1Score, p2: self.p2Score)
            }
        }
    }

    private func scheduleAutoAdvance(afterSeconds: Double) {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = Task { [weak self] in
            let nanos = UInt64(afterSeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard let self, !Task.isCancelled, !self.isCompleted else { return }

            let nextIndex = self.currentQIndex + 1
            self.advanceToQuestion(index: nextIndex, p1: self.p1Score, p2: self.p2Score)
        }
    }

    private func advanceToQuestion(index: Int, p1: Int, p2: Int) {
        self.autoAdvanceTask?.cancel()
        self.autoAdvanceTask = nil
        self.answerWatchdogTask?.cancel()
        self.answerWatchdogTask = nil

        self.p1Score = p1
        self.p2Score = p2

        if index != self.currentQIndex {
            self.currentQIndex = index
            self.selectedOptionKey = nil
            self.isLocked = false
            self.roundStatus = .idle
        } else if self.isLocked && self.roundStatus != .idle && self.selectedOptionKey == nil {
            self.isLocked = false
            self.roundStatus = .idle
        }

        if index >= self.battle.questions.count {
            self.isCompleted = true
            self.isDraw = p1 == p2
            if p1 > p2 {
                self.winnerId = self.battle.p1Id
            } else if p2 > p1 {
                self.winnerId = self.battle.p2Id
            }
        }
    }

    func selectOption(_ key: String) {
        guard !isLocked, selectedOptionKey == nil else { return }
        selectedOptionKey = key

        if isPractice {
            handlePracticeAnswer(key)
        } else {
            isLocked = true
            socket.emit(event: "submit_answer", payload: [
                "battleId": battle.battleId,
                "userId": currentUserId,
                "optionKey": key,
                "questionIndex": currentQIndex
            ])

            // Safety watchdog: re-sync state if server does not respond within 2.5s
            armSyncWatchdog(afterSeconds: 2.5)
        }
    }

    // MARK: - Bot Practice Simulation

    private func startPracticeMode() {
        scheduleBotAnswer()
    }

    private func scheduleBotAnswer() {
        botTask?.cancel()
        guard currentQIndex < battle.questions.count else { return }
        let currentQ = battle.questions[currentQIndex]

        let delayNanos = UInt64(Double.random(in: 3.0...5.5) * 1_000_000_000)

        botTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanos)
            guard let self, !Task.isCancelled, !self.isLocked else { return }

            let botWillBeCorrect = Double.random(in: 0...1) < 0.70
            if botWillBeCorrect {
                self.p2Score += 1
                self.roundStatus = .claimedByOpponent
                self.isLocked = true
                self.advancePracticeRound()
            } else {
                if self.roundStatus == .idle {
                    self.roundStatus = .opponentMissed
                }
            }
        }
    }

    private func handlePracticeAnswer(_ key: String) {
        botTask?.cancel()
        guard let currentQ = currentQuestion else { return }
        isLocked = true

        let isCorrect = isOptionCorrect(key: key, question: currentQ)
        if isCorrect {
            p1Score += 1
            roundStatus = .claimedByMe
        } else {
            roundStatus = .myAnswerWrong
        }
        advancePracticeRound()
    }

    private func isOptionCorrect(key: String, question: BattleQuestion) -> Bool {
        guard let correct = question.correctAnswer?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return key == (question.options.first?.id ?? "A")
        }
        if key.caseInsensitiveCompare(correct) == .orderedSame {
            return true
        }
        if let opt = question.options.first(where: { $0.id == key }) {
            return opt.text.caseInsensitiveCompare(correct) == .orderedSame
        }
        return false
    }

    private func advancePracticeRound() {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard let self else { return }
            if self.currentQIndex + 1 < self.battle.questions.count {
                self.currentQIndex += 1
                self.selectedOptionKey = nil
                self.isLocked = false
                self.roundStatus = .idle
                self.scheduleBotAnswer()
            } else {
                self.isCompleted = true
                self.isDraw = self.p1Score == self.p2Score
                if self.p1Score > self.p2Score {
                    self.winnerId = self.currentUserId
                } else if self.p2Score > self.p1Score {
                    self.winnerId = "aptibot-ai"
                }
            }
        }
    }

    func cleanup() {
        botTask?.cancel()
        autoAdvanceTask?.cancel()
        answerWatchdogTask?.cancel()
        socket.activeBattleId = nil
        socket.onBattleSync = nil
        socket.onQuestionResolved = nil
        socket.onAnswerIncorrect = nil
        socket.onOpponentMissed = nil
        socket.onNextQuestion = nil
        socket.onBattleCompleted = nil
    }
}


// MARK: - Views

struct BattleLobbyView: View {
    let token: String?
    let user: UserProfile?
    var initialAnalytics: StudentAnalytics? = nil

    @State private var model = BattleLobbyViewModel()
    @State private var elo: Int = 1000
    @State private var tier: EloTier = .initiate

    private var effectiveUserId: String {
        UserProfile.extractUserId(from: token) ?? user?.id ?? ""
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    PlayerBattleCard(
                        name: user?.name ?? "Student",
                        elo: elo,
                        tier: tier
                    )

                    Picker("Mode", selection: $model.mode) {
                        ForEach(BattleLobbyViewModel.MatchmakingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let error = model.errorMessage {
                        ErrorMessageView(message: error)
                    }

                    switch model.mode {
                    case .random:
                        RandomMatchSection(
                            isSearching: model.isSearching,
                            seconds: model.searchSeconds,
                            onFind: {
                                model.startRandomQueue(userId: effectiveUserId)
                            },
                            onCancel: {
                                model.cancelQueue()
                            }
                        )

                    case .chamber:
                        PrivateChamberSection(
                            createdRoomId: model.createdRoomId,
                            joinCode: $model.joinRoomCode,
                            isSearching: model.isSearching,
                            onCreate: {
                                model.createChamber(userId: effectiveUserId)
                            },
                            onDisband: {
                                model.disbandChamber()
                            },
                            onJoin: {
                                model.joinChamber(userId: effectiveUserId)
                            }
                        )

                    case .bot:
                        PracticeDuelSection(
                            isSearching: model.isSearching,
                            onStart: {
                                Task {
                                    await model.startPracticeMatch(
                                        userId: effectiveUserId,
                                        token: token
                                    )
                                }
                            }
                        )
                    }

                    BattleRulesCard()
                }
                .padding()
            }
            .navigationTitle("1v1 Arena")
            .navigationDestination(item: $model.activeBattle) { battle in
                BattleRoomView(
                    battle: battle,
                    currentUserId: effectiveUserId,
                    opponentName: model.isPractice ? "AptiBot AI" : "Challenger",
                    isPractice: model.isPractice,
                    onDismissAndReturn: {
                        model.resetBattleState()
                        Task {
                            await refreshAnalytics()
                        }
                    }
                )
            }
            .task {
                if let initialAnalytics, let e = initialAnalytics.elo {
                    self.elo = e
                    self.tier = EloTier.tier(for: e)
                }
                if !effectiveUserId.isEmpty {
                    model.setupSocket(userId: effectiveUserId)
                }
                await refreshAnalytics()
            }
        }
    }

    private func refreshAnalytics() async {
        guard let token = token ?? KeychainStore.token(), !token.isEmpty else { return }
        if let a = try? await APIClient.shared.studentAnalytics(token: token), let e = a.elo {
            self.elo = e
            self.tier = EloTier.tier(for: e)
        }
    }
}

struct PlayerBattleCard: View {
    let name: String
    let elo: Int
    let tier: EloTier

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(tier.color.opacity(0.18))
                    .frame(width: 60, height: 60)
                Image(systemName: tier.icon)
                    .font(.title2.bold())
                    .foregroundStyle(tier.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text("\(elo) ELO")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(tier.rawValue)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(tier.color.opacity(0.15), in: Capsule())
                        .foregroundStyle(tier.color)
                }
            }

            Spacer()

            Image(systemName: "flag.2.crossed.fill")
                .font(.title)
                .foregroundStyle(.orange.opacity(0.8))
        }
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct RandomMatchSection: View {
    let isSearching: Bool
    let seconds: Int
    let onFind: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            if isSearching {
                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.orange)
                        .padding(.top, 8)

                    Text("Finding Contender…")
                        .font(.headline)

                    Text("Searching within ±50 MMR")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(formatSeconds(seconds))
                        .font(.title3.monospacedDigit().bold())
                        .foregroundStyle(.secondary)

                    Button(role: .cancel, action: onCancel) {
                        Text("Cancel Matchmaking")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundStyle(.orange)
                        Text("Instant Matchmaking")
                            .font(.headline)
                    }
                    Text("Enter the live matchmaking queue. Contenders within ±50 Elo MMR will be matched automatically for a rapid 5-question speed duel.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button(action: onFind) {
                        Label("Find 1v1 Match", systemImage: "bolt.shield.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.large)
                }
                .padding()
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private func formatSeconds(_ s: Int) -> String {
        let mins = s / 60
        let secs = s % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

struct PrivateChamberSection: View {
    let createdRoomId: String?
    @Binding var joinCode: String
    let isSearching: Bool
    let onCreate: () -> Void
    let onDisband: () -> Void
    let onJoin: () -> Void

    @State private var hasCopied = false

    var body: some View {
        VStack(spacing: 18) {
            if let roomId = createdRoomId {
                VStack(spacing: 14) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.orange)
                        Text("Chamber Created")
                            .font(.headline)
                        Spacer()
                        Button("Disband", role: .destructive, action: onDisband)
                            .font(.caption)
                    }

                    Text("Share this 6-digit code with your challenger:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Text(roomId)
                            .font(.system(size: 32, weight: .black, design: .monospaced))
                            .kerning(4)
                            .foregroundStyle(.orange)

                        Button {
                            UIPasteboard.general.string = roomId
                            hasCopied = true
                            Task {
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                hasCopied = false
                            }
                        } label: {
                            Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                                .font(.headline)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding()
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Waiting for challenger to join…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 18))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(.orange)
                        Text("Host Private Chamber")
                            .font(.headline)
                    }
                    Text("Generate a direct 6-digit lobby passcode for a private match with a friend.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button(action: onCreate) {
                        Label("Host Chamber", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.large)
                }
                .padding()
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 18))
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.purple)
                    Text("Join Private Chamber")
                        .font(.headline)
                }

                TextField("ENTER 6-DIGIT PIN", text: $joinCode)
                    .font(.title3.monospaced().bold())
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.fill.secondary, in: RoundedRectangle(cornerRadius: 12))
                    .onSubmit {
                        if !joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onJoin()
                        }
                    }

                Button(action: onJoin) {
                    Group {
                        if isSearching {
                            ProgressView()
                        } else {
                            Label("Join Chamber", systemImage: "arrow.right.circle.fill")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.large)
                .disabled(joinCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 || isSearching)
            }
            .padding()
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}

struct PracticeDuelSection: View {
    let isSearching: Bool
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundStyle(.green)
                Text("Practice Duel vs AptiBot AI")
                    .font(.headline)
            }

            Text("Spar against an adaptive AI opponent that answers with realistic reaction times. Ideal for warmups when other contenders are offline.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(action: onStart) {
                Group {
                    if isSearching {
                        ProgressView()
                    } else {
                        Label("Start AI Practice Duel", systemImage: "play.fill")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)
            .disabled(isSearching)
        }
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct BattleRulesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("1v1 Arena Rules", systemImage: "info.circle.fill")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                RuleBullet(text: "Each match has 5 speed questions.")
                RuleBullet(text: "The first player to choose the correct answer claims the round point.")
                RuleBullet(text: "If you guess wrong, your options are locked while your opponent can still claim the point.")
                RuleBullet(text: "Winner gains ELO rating points; ties result in neutral rating changes.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct RuleBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.orange)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Battle Room View

struct BattleRoomView: View {
    let battle: BattleData
    let currentUserId: String
    let opponentName: String
    let isPractice: Bool
    var onDismissAndReturn: (() -> Void)? = nil

    @State private var model: BattleRoomViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        battle: BattleData,
        currentUserId: String,
        opponentName: String = "Opponent",
        isPractice: Bool = false,
        onDismissAndReturn: (() -> Void)? = nil
    ) {
        self.battle = battle
        self.currentUserId = currentUserId
        self.opponentName = opponentName
        self.isPractice = isPractice
        self.onDismissAndReturn = onDismissAndReturn
        _model = State(initialValue: BattleRoomViewModel(
            battle: battle,
            currentUserId: currentUserId,
            opponentName: opponentName,
            isPractice: isPractice
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            BattleVersusHeader(
                myName: "You",
                myScore: model.myScore,
                opponentName: opponentName,
                opponentScore: model.opponentScore,
                questionIndex: min(model.currentQIndex + 1, model.battle.questions.count),
                totalQuestions: model.battle.questions.count
            )

            if model.isCompleted || model.currentQIndex >= model.battle.questions.count {
                BattleResultView(
                    myScore: model.myScore,
                    opponentScore: model.opponentScore,
                    winnerId: model.winnerId,
                    currentUserId: currentUserId,
                    isDraw: model.isDraw,
                    eloChange: model.eloChange,
                    onDismiss: {
                        model.cleanup()
                        dismiss()
                        onDismissAndReturn?()
                    }
                )
            } else if let question = model.currentQuestion {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            if let type = question.type {
                                Text(type)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.orange.opacity(0.18), in: Capsule())
                                    .foregroundStyle(.orange)
                            }
                            Spacer()
                            Text("Speed Round")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }

                        Text(question.questionText)
                            .font(.title3.bold())
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Image(systemName: model.roundStatus.icon)
                                .foregroundStyle(model.roundStatus.color)
                            Text(model.roundStatus.title)
                                .font(.footnote.bold())
                                .foregroundStyle(model.roundStatus.color)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(model.roundStatus.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                        VStack(spacing: 12) {
                            ForEach(question.options) { opt in
                                BattleOptionButton(
                                    option: opt,
                                    isSelected: model.selectedOptionKey == opt.id,
                                    isLocked: model.isLocked,
                                    roundStatus: model.roundStatus,
                                    correctAnswer: question.correctAnswer,
                                    onSelect: {
                                        model.selectOption(opt.id)
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                }
                .id(model.currentQIndex)
            } else {
                ProgressView("Finalizing scores…")
                    .frame(maxHeight: .infinity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Forfeit") {
                    model.cleanup()
                    dismiss()
                    onDismissAndReturn?()
                }
                .foregroundStyle(.red)
            }
        }
        .task {
            model.start()
        }
        .onDisappear {
            model.cleanup()
        }
    }
}

struct BattleVersusHeader: View {
    let myName: String
    let myScore: Int
    let opponentName: String
    let opponentScore: Int
    let questionIndex: Int
    let totalQuestions: Int

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                // My Side
                HStack(spacing: 10) {
                    Circle()
                        .fill(.blue.opacity(0.2))
                        .frame(width: 38, height: 38)
                        .overlay(Image(systemName: "person.fill").foregroundStyle(.blue))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(myName)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text("\(myScore)")
                            .font(.title2.bold())
                    }
                }

                Spacer()

                // VS Badge
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.2.crossed.fill")
                            .font(.caption2)
                        Text("VS")
                            .font(.caption2.bold())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.orange.opacity(0.2), in: Capsule())
                    .foregroundStyle(.orange)

                    Text("Q \(questionIndex)/\(totalQuestions)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Opponent Side
                HStack(spacing: 10) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(opponentName)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text("\(opponentScore)")
                            .font(.title2.bold())
                    }

                    Circle()
                        .fill(.purple.opacity(0.2))
                        .frame(width: 38, height: 38)
                        .overlay(Image(systemName: "person.fill").foregroundStyle(.purple))
                }
            }
            .padding(.horizontal)

            ProgressView(value: Double(questionIndex), total: Double(totalQuestions))
                .tint(.orange)
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.fill.tertiary)
    }
}

struct BattleOptionButton: View {
    let option: QuizOption
    let isSelected: Bool
    let isLocked: Bool
    let roundStatus: BattleRoundStatus
    let correctAnswer: String?
    let onSelect: () -> Void

    var isOptionCorrect: Bool {
        guard let correct = correctAnswer?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return option.id.caseInsensitiveCompare(correct) == .orderedSame || option.text.caseInsensitiveCompare(correct) == .orderedSame
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Text(option.id)
                    .font(.subheadline.bold())
                    .frame(width: 28, height: 28)
                    .background(badgeBackground, in: Circle())
                    .foregroundStyle(badgeForeground)

                Text(option.text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: roundStatus == .myAnswerWrong ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(roundStatus == .myAnswerWrong ? .red : .orange)
                }
            }
            .padding(14)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderStroke, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLocked || isSelected)
    }

    private var badgeBackground: Color {
        if isOptionCorrect && roundStatus != .idle {
            return .green
        }
        if isSelected {
            return roundStatus == .myAnswerWrong ? .red : .orange
        }
        return Color(.secondarySystemFill)
    }

    private var badgeForeground: Color {
        if isOptionCorrect && roundStatus != .idle {
            return .white
        }
        if isSelected { return .white }
        return .primary
    }

    private var cardBackground: Color {
        if isOptionCorrect && roundStatus != .idle {
            return .green.opacity(0.12)
        }
        if isSelected {
            return (roundStatus == .myAnswerWrong ? Color.red : Color.orange).opacity(0.12)
        }
        return Color(.secondarySystemBackground)
    }

    private var borderStroke: Color {
        if isOptionCorrect && roundStatus != .idle {
            return .green
        }
        if isSelected {
            return roundStatus == .myAnswerWrong ? .red : .orange
        }
        return .clear
    }
}

// MARK: - Battle Result View

struct BattleResultView: View {
    let myScore: Int
    let opponentScore: Int
    let winnerId: String?
    let currentUserId: String
    let isDraw: Bool
    var eloChange: Int? = nil
    let onDismiss: () -> Void

    var isVictory: Bool {
        winnerId == currentUserId || (!isDraw && myScore > opponentScore)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Result Icon & Headline
                VStack(spacing: 12) {
                    if isDraw {
                        ZStack {
                            Circle()
                                .fill(.blue.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Image(systemName: "flag.2.crossed.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.blue)
                        }
                        Text("DRAW GAME")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.primary)
                        Text("Evenly matched duelists! Both claimed an equal share of speed points.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else if isVictory {
                        ZStack {
                            Circle()
                                .fill(.yellow.opacity(0.18))
                                .frame(width: 80, height: 80)
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.yellow)
                        }
                        Text("VICTORY!")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.primary)
                        Text("Outstanding reflexes and accuracy! You dominated the speed duel.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        ZStack {
                            Circle()
                                .fill(.red.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Image(systemName: "shield.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.red)
                        }
                        Text("DEFEAT")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.primary)
                        Text("Close match! Fast-fingered speed makes all the difference.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 16)

                // MMR / ELO Pill
                if let change = eloChange {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                        Text("MMR UPDATE:")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(change >= 0 ? "+\(change) ELO" : "\(change) ELO")
                            .font(.subheadline.bold())
                            .foregroundStyle(change > 0 ? .green : (change < 0 ? .red : .secondary))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.fill.tertiary, in: Capsule())
                }

                // Duel Scores Comparison
                HStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("YOU")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                        Text("\(myScore)")
                            .font(.system(size: 54, weight: .heavy, design: .rounded))
                            .foregroundStyle(.orange)
                        if isVictory {
                            Text("Winner")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.green.opacity(0.2), in: Capsule())
                                .foregroundStyle(.green)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isVictory ? .green.opacity(0.4) : .clear, lineWidth: 1.5)
                    )

                    VStack(spacing: 8) {
                        Text("OPPONENT")
                            .font(.caption.bold())
                            .foregroundStyle(.purple)
                        Text("\(opponentScore)")
                            .font(.system(size: 54, weight: .heavy, design: .rounded))
                            .foregroundStyle(.purple)
                        if !isVictory && !isDraw {
                            Text("Winner")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.red.opacity(0.2), in: Capsule())
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(!isVictory && !isDraw ? .red.opacity(0.4) : .clear, lineWidth: 1.5)
                    )
                }

                Spacer(minLength: 24)

                // Return Button
                Button(action: onDismiss) {
                    Label("Return to Arena Lobby", systemImage: "flag.2.crossed.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.large)
            }
            .padding(24)
        }
    }
}
