import { Server, Socket } from 'socket.io';
import { prisma } from '../../lib/prisma.js';

// Matchmaking queue
let queue: { socket: Socket; userId: string; elo: number; joinedAt: number }[] = [];

// Map to track private rooms
const privateRooms = new Map<string, { socket: Socket; userId: string }>();
const generateShortId = () => Math.random().toString(36).substring(2, 8).toUpperCase();

// Fallback MCQ pool to ensure 1v1 duel always has at least 5 valid MCQ questions
const fallbackBattleQuestions = [
  {
    id: "mcq_1",
    questionText: "A train traveling at 72 km/h crosses a 260 m long platform in 23 seconds. What is the length of the train?",
    options: { A: "200 m", B: "220 m", C: "240 m", D: "180 m" },
    correctAnswer: "A",
    type: "MCQ"
  },
  {
    id: "mcq_2",
    questionText: "If 15 men can complete a project in 12 days working 8 hours a day, how many days will 18 men take working 6 hours a day?",
    options: { A: "10 days", B: "13.3 days", C: "15 days", D: "12 days" },
    correctAnswer: "B",
    type: "MCQ"
  },
  {
    id: "mcq_3",
    questionText: "The ratio of present ages of A and B is 3:5. After 6 years, the ratio becomes 2:3. What is B's present age?",
    options: { A: "25 years", B: "30 years", C: "35 years", D: "20 years" },
    correctAnswer: "B",
    type: "MCQ"
  },
  {
    id: "mcq_4",
    questionText: "A shopkeeper marks an article 40% above cost price and allows a 20% discount. What is the net profit percentage?",
    options: { A: "12%", B: "15%", C: "20%", D: "8%" },
    correctAnswer: "A",
    type: "MCQ"
  },
  {
    id: "mcq_5",
    questionText: "Pointing to a photograph, a woman says: 'He is the only son of my father\\'s father.' How is the man related to the woman?",
    options: { A: "Father", B: "Uncle", C: "Brother", D: "Grandfather" },
    correctAnswer: "A",
    type: "MCQ"
  },
  {
    id: "mcq_6",
    questionText: "Find the next number in the series: 4, 9, 25, 49, 121, ?",
    options: { A: "144", B: "169", C: "196", D: "225" },
    correctAnswer: "B",
    type: "MCQ"
  },
  {
    id: "mcq_7",
    questionText: "Pipe A can fill a tank in 6 hours and Pipe B can empty it in 8 hours. If both are opened together, how long will it take to fill the tank?",
    options: { A: "24 hours", B: "14 hours", C: "18 hours", D: "12 hours" },
    correctAnswer: "A",
    type: "MCQ"
  }
];

// Active battles state map
interface ActiveBattle {
  battleId: string;
  p1: { userId: string; socketId?: string; score: number };
  p2: { userId: string; socketId?: string; score: number };
  questions: any[];
  currentQIndex: number;
  questionClaimed: boolean;
  claimedBy: string | null;
  wrongAttempts: Set<string>;
  advanceTimeout?: NodeJS.Timeout;
  questionSafetyTimeout?: NodeJS.Timeout;
}

const activeBattles = new Map<string, ActiveBattle>();

function shuffleArray<T>(array: T[]): T[] {
  const result = [...array];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

// Robust answer correctness checker matching iOS logic
function checkAnswerCorrectness(question: any, optionKey: string): boolean {
  if (!question) return false;
  const rawCorrect = (question.correctAnswer || '').toString().trim();
  const rawKey = (optionKey || '').toString().trim();

  if (!rawKey) return false;

  // 1. Direct case-insensitive match (e.g. "A" === "a" or "200 m" === "200 m")
  if (rawCorrect.toLowerCase() === rawKey.toLowerCase()) {
    return true;
  }

  // 2. Options as Object { "A": "200 m", "B": "220 m" }
  const options = question.options;
  if (options && typeof options === 'object' && !Array.isArray(options)) {
    const textForKey = options[rawKey] || options[rawKey.toUpperCase()] || options[rawKey.toLowerCase()];
    if (textForKey && String(textForKey).trim().toLowerCase() === rawCorrect.toLowerCase()) {
      return true;
    }
    const textForCorrect = options[rawCorrect] || options[rawCorrect.toUpperCase()] || options[rawCorrect.toLowerCase()];
    if (textForCorrect && String(textForCorrect).trim().toLowerCase() === rawKey.toLowerCase()) {
      return true;
    }
  }

  // 3. Options as Array ["200 m", "220 m"] or [{id: "A", text: "200 m"}]
  if (Array.isArray(options)) {
    const letterIdx = rawKey.toUpperCase().charCodeAt(0) - 65;
    if (letterIdx >= 0 && letterIdx < options.length) {
      const opt = options[letterIdx];
      const optText = typeof opt === 'string' ? opt : (opt.text || opt.label || opt.value || '');
      if (optText && String(optText).trim().toLowerCase() === rawCorrect.toLowerCase()) {
        return true;
      }
    }

    for (let i = 0; i < options.length; i++) {
      const opt = options[i];
      if (typeof opt === 'object' && opt !== null) {
        const id = (opt.id || opt.key || opt.optionKey || String.fromCharCode(65 + i)).toString().trim();
        const text = (opt.text || opt.label || opt.value || '').toString().trim();
        if (id.toLowerCase() === rawKey.toLowerCase() && text.toLowerCase() === rawCorrect.toLowerCase()) {
          return true;
        }
      }
    }
  }

  return false;
}

async function getRandomBattleQuestions(count: number = 5): Promise<any[]> {
  try {
    let candidates = await prisma.question.findMany({
      where: {
        status: 'PUBLISHED',
        type: 'MCQ'
      },
      select: { id: true, options: true }
    });

    const hasMinOptions = (opts: any) => {
      if (!opts) return false;
      if (Array.isArray(opts)) return opts.length >= 2;
      if (typeof opts === 'object') return Object.keys(opts).length >= 2;
      return false;
    };

    let validCandidates = candidates.filter(c => hasMinOptions(c.options));

    if (validCandidates.length === 0) {
      candidates = await prisma.question.findMany({
        where: { type: 'MCQ' },
        select: { id: true, options: true }
      });
      validCandidates = candidates.filter(c => hasMinOptions(c.options));
    }

    const selectedIds = shuffleArray(validCandidates)
      .slice(0, count)
      .map(c => c.id);

    let questions: any[] = [];
    if (selectedIds.length > 0) {
      questions = await prisma.question.findMany({
        where: { id: { in: selectedIds } }
      });
    }

    // Top up with fallbacks if DB returns fewer than requested
    if (questions.length < count) {
      const needed = count - questions.length;
      const shuffledFallbacks = shuffleArray(fallbackBattleQuestions).filter(
        fb => !questions.some(q => q.id === fb.id)
      );
      questions = [...questions, ...shuffledFallbacks.slice(0, needed)];
    }

    return shuffleArray(questions);
  } catch (err) {
    console.error('Error fetching battle questions, using fallbacks:', err);
    return shuffleArray(fallbackBattleQuestions).slice(0, count);
  }
}

function scheduleNextQuestion(battleId: string, io: Server, delayMs: number = 1200) {
  const battle = activeBattles.get(battleId);
  if (!battle) return;

  if (battle.advanceTimeout) {
    clearTimeout(battle.advanceTimeout);
  }
  if (battle.questionSafetyTimeout) {
    clearTimeout(battle.questionSafetyTimeout);
  }

  battle.advanceTimeout = setTimeout(async () => {
    const currentBattle = activeBattles.get(battleId);
    if (!currentBattle) return;

    currentBattle.currentQIndex += 1;
    currentBattle.questionClaimed = false;
    currentBattle.claimedBy = null;
    currentBattle.wrongAttempts.clear();

    if (currentBattle.currentQIndex < currentBattle.questions.length) {
      io.to(battleId).emit('next_question', {
        currentQIndex: currentBattle.currentQIndex,
        p1Score: currentBattle.p1.score,
        p2Score: currentBattle.p2.score
      });
      armQuestionSafetyTimer(battleId, currentBattle.currentQIndex, io);
    } else {
      await finalizeBattle(battleId, currentBattle, io);
    }
  }, delayMs);
}

function armQuestionSafetyTimer(battleId: string, questionIndex: number, io: Server, timeoutMs: number = 25000) {
  const battle = activeBattles.get(battleId);
  if (!battle) return;

  if (battle.questionSafetyTimeout) {
    clearTimeout(battle.questionSafetyTimeout);
  }

  battle.questionSafetyTimeout = setTimeout(() => {
    const currentBattle = activeBattles.get(battleId);
    if (!currentBattle || currentBattle.currentQIndex !== questionIndex || currentBattle.questionClaimed) {
      return;
    }

    const currentQuestion = currentBattle.questions[currentBattle.currentQIndex];
    currentBattle.questionClaimed = true;

    io.to(battleId).emit('question_resolved', {
      questionIndex: currentBattle.currentQIndex,
      claimedBy: null,
      isCorrect: false,
      correctAnswer: currentQuestion?.correctAnswer || '',
      selectedOption: null,
      p1Score: currentBattle.p1.score,
      p2Score: currentBattle.p2.score
    });

    scheduleNextQuestion(battleId, io, 1200);
  }, timeoutMs);
}

async function finalizeBattle(battleId: string, battle: ActiveBattle, io: Server) {
  try {
    if (battle.advanceTimeout) {
      clearTimeout(battle.advanceTimeout);
    }
    if (battle.questionSafetyTimeout) {
      clearTimeout(battle.questionSafetyTimeout);
    }

    let winnerId: string | null = null;
    if (battle.p1.score > battle.p2.score) {
      winnerId = battle.p1.userId;
    } else if (battle.p2.score > battle.p1.score) {
      winnerId = battle.p2.userId;
    }

    // Update Battle record in DB if exists
    try {
      await prisma.battle.update({
        where: { id: battleId },
        data: {
          status: 'COMPLETED',
          winnerId: winnerId || undefined
        }
      });
    } catch (_) {}

    // Update ELO and streaks using dynamic Elo formula
    const winnerData = winnerId
      ? await prisma.user.findUnique({
          where: { id: winnerId },
          select: { elo: true, currentStreak: true, longestStreak: true }
        })
      : null;

    const loserId = winnerId
      ? (winnerId === battle.p1.userId ? battle.p2.userId : battle.p1.userId)
      : null;

    const loserData = loserId
      ? await prisma.user.findUnique({
          where: { id: loserId },
          select: { elo: true }
        })
      : null;

    let winnerEloChange = 0;
    let loserEloChange = 0;

    if (winnerId && winnerData && loserId && loserData) {
      const K = 32; // base K-factor
      const totalQs = battle.questions.length || 5;
      const winnerScore = winnerId === battle.p1.userId ? battle.p1.score : battle.p2.score;
      const loserScore = winnerId === battle.p1.userId ? battle.p2.score : battle.p1.score;

      // Expected win probability (standard Elo formula)
      const expectedWin = 1 / (1 + Math.pow(10, (loserData.elo - winnerData.elo) / 400));

      // Margin bonus: dominating 5-0 earns more than scraping 3-2
      const marginBonus = (winnerScore - loserScore) / totalQs; // 0 to 1

      // Streak multiplier: 5% extra per consecutive win (capped at 50%)
      const streak = (winnerData.currentStreak || 0);
      const streakMultiplier = 1 + Math.min(streak * 0.05, 0.5);

      // Winner gains: higher when beating stronger opponents, with margin & streak bonuses
      winnerEloChange = Math.round(K * (1 - expectedWin) * (1 + marginBonus) * streakMultiplier);
      winnerEloChange = Math.max(5, Math.min(winnerEloChange, 60)); // clamp [5, 60]

      // Loser loses: more when losing to a weaker opponent
      loserEloChange = Math.round(K * (0 - expectedWin) * (1 + marginBonus * 0.5));
      loserEloChange = Math.max(-40, Math.min(loserEloChange, -3)); // clamp [-40, -3]

      // Update winner
      const newWinnerElo = winnerData.elo + winnerEloChange;
      const newStreak = streak + 1;
      await prisma.user.update({
        where: { id: winnerId },
        data: {
          elo: newWinnerElo,
          currentStreak: newStreak,
          longestStreak: Math.max(newStreak, winnerData.longestStreak || 0),
          lastActiveAt: new Date()
        }
      });
      await prisma.eloHistory.create({
        data: { userId: winnerId, elo: newWinnerElo }
      });

      // Update loser (floor at 1000)
      const newLoserElo = Math.max(1000, loserData.elo + loserEloChange);
      loserEloChange = newLoserElo - loserData.elo; // recalculate in case of floor
      await prisma.user.update({
        where: { id: loserId },
        data: {
          elo: newLoserElo,
          currentStreak: 0,
          lastActiveAt: new Date()
        }
      });
      await prisma.eloHistory.create({
        data: { userId: loserId, elo: newLoserElo }
      });
    }

    io.to(battleId).emit('battle_completed', {
      battleId,
      p1Score: battle.p1.score,
      p2Score: battle.p2.score,
      winnerId,
      isDraw: battle.p1.score === battle.p2.score,
      eloChanges: {
        [battle.p1.userId]: winnerId === battle.p1.userId ? winnerEloChange : loserEloChange,
        [battle.p2.userId]: winnerId === battle.p2.userId ? winnerEloChange : loserEloChange,
      }
    });

    activeBattles.delete(battleId);
  } catch (err) {
    console.error('Error finalizing battle:', err);
  }
}

export const setupBattleGateway = (io: Server) => {
  io.on('connection', (socket) => {
    console.log(`User connected to Battle Gateway: ${socket.id}`);

    socket.on('join_queue', async (data) => {
      const { userId } = data;
      if (!userId) return;

      console.log(`User ${userId} joined queue`);

      if (queue.find(p => p.userId === userId && p.socket.id === socket.id)) return;

      const user = await prisma.user.findUnique({ where: { id: userId }, select: { elo: true } });
      const userElo = user?.elo || 1000;

      const opponentIndex = queue.findIndex(p => Math.abs(p.elo - userElo) <= 250 && p.userId !== userId);

      if (opponentIndex !== -1) {
        const player1 = queue.splice(opponentIndex, 1)[0];
        const player2 = { socket, userId, elo: userElo, joinedAt: Date.now() };

        const questions = await getRandomBattleQuestions(5);

        let battleId = `battle_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
        try {
          const dbBattle = await prisma.battle.create({
            data: {
              player1Id: player1.userId,
              player2Id: player2.userId,
              status: 'IN_PROGRESS',
              questions: {
                connect: questions.filter(q => q.id && !q.id.startsWith('mcq_')).map(q => ({ id: q.id }))
              }
            }
          });
          battleId = dbBattle.id;
        } catch (_) {}

        const battleState: ActiveBattle = {
          battleId,
          p1: { userId: player1.userId, socketId: player1.socket.id, score: 0 },
          p2: { userId: player2.userId, socketId: player2.socket.id, score: 0 },
          questions,
          currentQIndex: 0,
          questionClaimed: false,
          claimedBy: null,
          wrongAttempts: new Set<string>()
        };

        activeBattles.set(battleId, battleState);

        player1.socket.join(battleId);
        player2.socket.join(battleId);

        const matchPayload = {
          battleId,
          p1Id: player1.userId,
          p2Id: player2.userId,
          questions
        };

        // Emit directly to sockets AND to room for zero-latency instant delivery
        player1.socket.emit('match_found', matchPayload);
        player2.socket.emit('match_found', matchPayload);
        io.to(battleId).emit('match_found', matchPayload);

        // Start 25s safety countdown for first question
        armQuestionSafetyTimer(battleId, 0, io);
      } else {
        queue.push({ socket, userId, elo: userElo, joinedAt: Date.now() });
      }
    });

    socket.on('leave_queue', () => {
      queue = queue.filter(p => p.socket.id !== socket.id);
    });

    socket.on('create_private_room', (data) => {
      const { userId } = data;
      if (!userId) return;

      const roomId = generateShortId();
      privateRooms.set(roomId, { socket, userId });
      socket.join(`room_${roomId}`);
      socket.emit('private_room_created', { roomId });
    });

    socket.on('join_private_room', async (data) => {
      const { userId, roomId } = data;
      if (!userId || !roomId) return;

      const normalizedRoomId = String(roomId).trim().toUpperCase();
      const host = privateRooms.get(normalizedRoomId);
      if (!host) {
        socket.emit('room_error', { message: 'Chamber not found or duel already started.' });
        return;
      }
      if (host.userId === userId && host.socket.id === socket.id) {
        socket.emit('room_error', { message: 'You cannot join your own chamber.' });
        return;
      }

      const player1 = host;
      const player2 = { socket, userId };
      privateRooms.delete(normalizedRoomId);

      const questions = await getRandomBattleQuestions(5);

      let battleId = `battle_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      try {
        const dbBattle = await prisma.battle.create({
          data: {
            player1Id: player1.userId,
            player2Id: player2.userId,
            status: 'IN_PROGRESS',
            questions: {
              connect: questions.filter(q => q.id && !q.id.startsWith('mcq_')).map(q => ({ id: q.id }))
            }
          }
        });
        battleId = dbBattle.id;
      } catch (_) {}

      const battleState: ActiveBattle = {
        battleId,
        p1: { userId: player1.userId, socketId: player1.socket.id, score: 0 },
        p2: { userId: player2.userId, socketId: player2.socket.id, score: 0 },
        questions,
        currentQIndex: 0,
        questionClaimed: false,
        claimedBy: null,
        wrongAttempts: new Set<string>()
      };

      activeBattles.set(battleId, battleState);

      player1.socket.join(battleId);
      player2.socket.join(battleId);

      const matchPayload = {
        battleId,
        p1Id: player1.userId,
        p2Id: player2.userId,
        questions
      };

      // Emit directly to both sockets AND room to ensure instant match start
      player1.socket.emit('match_found', matchPayload);
      player2.socket.emit('match_found', matchPayload);
      io.to(battleId).emit('match_found', matchPayload);

      armQuestionSafetyTimer(battleId, 0, io);
    });

    socket.on('cancel_private_room', (data) => {
      const { roomId } = data;
      if (roomId) {
        const normalized = String(roomId).trim().toUpperCase();
        privateRooms.delete(normalized);
      }
    });

    socket.on('join_battle', (data) => {
      const { battleId, userId } = data;
      if (!battleId) return;
      socket.join(battleId);

      const battle = activeBattles.get(battleId);
      if (battle) {
        // Re-associate socket ID on reconnect
        if (userId === battle.p1.userId) {
          battle.p1.socketId = socket.id;
        } else if (userId === battle.p2.userId) {
          battle.p2.socketId = socket.id;
        }

        const isP1 = (userId && userId === battle.p1.userId) || socket.id === battle.p1.socketId;
        const isP2 = (userId && userId === battle.p2.userId) || socket.id === battle.p2.socketId;
        const playerTag = isP1 ? 'P1' : (isP2 ? 'P2' : (userId || socket.id));

        socket.emit('battle_sync', {
          currentQIndex: battle.currentQIndex,
          p1Score: battle.p1.score,
          p2Score: battle.p2.score,
          p1Id: battle.p1.userId,
          p2Id: battle.p2.userId,
          questionClaimed: battle.questionClaimed,
          claimedBy: battle.claimedBy,
          isLocked: battle.questionClaimed || battle.wrongAttempts.has(playerTag) || battle.wrongAttempts.has(userId) || battle.wrongAttempts.has(socket.id)
        });
      }
    });

    socket.on('submit_answer', async (data) => {
      const { battleId, userId, optionKey, questionIndex } = data;
      const battle = activeBattles.get(battleId);
      if (!battle) return;

      const qIdx = Number(questionIndex);

      // Resync immediately if question index mismatches server state
      if (isNaN(qIdx) || qIdx !== battle.currentQIndex) {
        socket.emit('battle_sync', {
          currentQIndex: battle.currentQIndex,
          p1Score: battle.p1.score,
          p2Score: battle.p2.score,
          p1Id: battle.p1.userId,
          p2Id: battle.p2.userId,
          questionClaimed: battle.questionClaimed,
          claimedBy: battle.claimedBy,
          isLocked: battle.questionClaimed || battle.wrongAttempts.has(userId) || battle.wrongAttempts.has(socket.id)
        });
        return;
      }

      // If question is already claimed, update client immediately so it is not stuck
      if (battle.questionClaimed) {
        const currentQ = battle.questions[battle.currentQIndex];
        socket.emit('question_resolved', {
          questionIndex: battle.currentQIndex,
          claimedBy: battle.claimedBy,
          isCorrect: battle.claimedBy === userId,
          correctAnswer: currentQ?.correctAnswer || '',
          selectedOption: optionKey,
          p1Score: battle.p1.score,
          p2Score: battle.p2.score
        });
        return;
      }

      const isP1 = (userId && userId === battle.p1.userId) || socket.id === battle.p1.socketId;
      const isP2 = (userId && userId === battle.p2.userId) || socket.id === battle.p2.socketId;
      const playerTag = isP1 ? 'P1' : (isP2 ? 'P2' : (userId || socket.id));

      // Ignore if this user already missed this question
      if (battle.wrongAttempts.has(playerTag) || battle.wrongAttempts.has(userId) || battle.wrongAttempts.has(socket.id)) {
        return;
      }

      const currentQuestion = battle.questions[battle.currentQIndex];
      if (!currentQuestion) return;

      const isCorrect = checkAnswerCorrectness(currentQuestion, optionKey);

      if (isCorrect) {
        // Player answered CORRECT first -> claims the point immediately!
        battle.questionClaimed = true;
        const winnerUserId = isP1 ? battle.p1.userId : (isP2 ? battle.p2.userId : userId);
        battle.claimedBy = winnerUserId;

        if (isP1 || winnerUserId === battle.p1.userId) {
          battle.p1.score += 1;
        } else {
          battle.p2.score += 1;
        }

        // Emit IMMEDIATELY so score reflects on both screens right away
        io.to(battleId).emit('question_resolved', {
          questionIndex: battle.currentQIndex,
          claimedBy: winnerUserId,
          isCorrect: true,
          correctAnswer: currentQuestion.correctAnswer,
          selectedOption: optionKey,
          p1Score: battle.p1.score,
          p2Score: battle.p2.score
        });

        // Fast responsive advance after 1.2s
        scheduleNextQuestion(battleId, io, 1200);

      } else {
        // Player answered INCORRECT -> locked out of this question!
        battle.wrongAttempts.add(playerTag);
        if (userId) battle.wrongAttempts.add(userId);
        battle.wrongAttempts.add(socket.id);

        // Notify the answering player that their answer was wrong
        socket.emit('answer_incorrect', {
          questionIndex: battle.currentQIndex,
          selectedOption: optionKey
        });

        // Notify opponent that the challenger missed, point is still up for grabs
        socket.to(battleId).emit('opponent_missed', {
          questionIndex: battle.currentQIndex
        });

        // If both players attempted and missed, reveal correct answer and advance
        const bothMissed = (battle.wrongAttempts.has('P1') && battle.wrongAttempts.has('P2'))
          || battle.wrongAttempts.size >= 2;

        if (bothMissed) {
          battle.questionClaimed = true;
          io.to(battleId).emit('question_resolved', {
            questionIndex: battle.currentQIndex,
            claimedBy: null,
            isCorrect: false,
            correctAnswer: currentQuestion.correctAnswer,
            selectedOption: optionKey,
            p1Score: battle.p1.score,
            p2Score: battle.p2.score
          });

          scheduleNextQuestion(battleId, io, 1200);
        }
      }
    });

    socket.on('disconnect', () => {
      console.log(`User disconnected: ${socket.id}`);
      queue = queue.filter(p => p.socket.id !== socket.id);
    });
  });
};
