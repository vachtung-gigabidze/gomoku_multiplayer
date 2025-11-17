import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  User? get currentUser => _client.auth.currentUser;

  // Инициализация
  static Future<void> initialize() async {
    await Supabase.initialize(url: dotenv.env['SUPABASE_URL'] ?? "SUPABASE_URL", anonKey: dotenv.env['SUPABASE_ANONKEY'] ?? "SUPABASE_ANONKEY");
  }

  // Аутентификация по OTP
  Future<void> signUpWithOTP(String email, String username) async {
    final authResponse = await _client.auth.signInWithOtp(email: email, data: {'username': username}, emailRedirectTo: 'app.supabase.gomoku://login-callback');

    return authResponse;
  }

  // Получение текущего пользователя
  Future<User?> getCurrentUser() async {
    return _client.auth.currentUser;
  }

  // Упрощенная OTP аутентификация
  Future<void> signInWithOTP(String email, {String? username}) async {
    try {
      await _client.auth.signInWithOtp(
        email: email,
        data: username != null ? {'username': username} : null,
        emailRedirectTo: null, // Убираем redirect для мобильных
      );
    } catch (e) {
      if (kDebugMode) {
        print('OTP Sign In Error: $e');
      }
      rethrow;
    }
  }

  // Подтверждение OTP
  Future<AuthResponse> verifyOTP(String email, String token) async {
    try {
      final response = await _client.auth.verifyOTP(email: email, token: token, type: OtpType.email);

      // Если это регистрация, создаем профиль
      if (response.user != null) {
        final username = response.user!.userMetadata?['username'] as String?;
        if (username != null) {
          await _createProfile(response.user!.id, username);
        }
      }

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('OTP Verification Error: $e');
      }
      rethrow;
    }
  }

  // Повторная отправка OTP
  Future<void> resendOTP(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email, emailRedirectTo: 'app.supabase.gomoku://login-callback');
  }

  // Выход
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Создание профиля
  Future<void> _createProfile(String userId, String username) async {
    try {
      await _client.from('profiles').upsert({'id': userId, 'username': username, 'updated_at': DateTime.now().toIso8601String()});
    } catch (e) {
      // Игнорируем ошибки если профиль уже существует
      if (kDebugMode) {
        print('Profile creation error: $e');
      }
    }
  }

  // СОЗДАНИЕ КОМНАТЫ
  Future<Map<String, dynamic>> createRoom(String roomName) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Инициализируем пустую доску 15x15
    final initialBoard = List.generate(15, (_) => List.filled(15, 0));

    final response = await _client
        .from('rooms')
        .insert({
          'name': roomName,
          'created_by': user.id,
          'game_state': {'board': initialBoard, 'currentPlayer': 1, 'gameStarted': false, 'gameOver': false, 'winner': null, 'lastMove': null},
          'players': [
            {'id': user.id, 'username': user.userMetadata?['username'] ?? 'Player', 'playerNumber': 1, 'joined_at': DateTime.now().toIso8601String()},
          ],
          'spectators': [],
        })
        .select()
        .single();

    return response;
  }

  // ПОЛУЧЕНИЕ СПИСКА КОМНАТ
  Future<List<Map<String, dynamic>>> getRooms() async {
    final response = await _client.from('rooms').select('*').order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // ПРИСОЕДИНЕНИЕ К КОМНАТЕ
  Future<Map<String, dynamic>> joinRoom(String roomId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Получаем текущую комнату
    final room = await _client.from('rooms').select('*').eq('id', roomId).single() as Map<String, dynamic>;

    final players = List<Map<String, dynamic>>.from(room['players']);
    final spectators = List<Map<String, dynamic>>.from(room['spectators']);

    // Проверяем, не присоединен ли уже пользователь
    if (players.any((p) => p['id'] == user.id) || spectators.any((s) => s['id'] == user.id)) {
      return {
        'success': true,
        'role': players.any((p) => p['id'] == user.id) ? 'player' : 'spectator',
        'playerNumber': players.firstWhere((p) => p['id'] == user.id, orElse: () => {})['playerNumber'] ?? 0,
        'room': room,
      };
    }

    // Присоединяем как игрок или зритель
    if (players.length < 2) {
      final newPlayer = {'id': user.id, 'username': user.userMetadata?['username'] ?? 'Player', 'playerNumber': players.length + 1, 'joined_at': DateTime.now().toIso8601String()};

      players.add(newPlayer);

      final updatedRoom = await _client.from('rooms').update({'players': players, 'updated_at': DateTime.now().toIso8601String()}).eq('id', roomId).select().single() as Map<String, dynamic>;

      return {'success': true, 'role': 'player', 'playerNumber': players.length, 'room': updatedRoom};
    } else {
      // Присоединяемся как зритель
      final newSpectator = {'id': user.id, 'username': user.userMetadata?['username'] ?? 'Player', 'joined_at': DateTime.now().toIso8601String()};

      spectators.add(newSpectator);

      final updatedRoom = await _client.from('rooms').update({'spectators': spectators, 'updated_at': DateTime.now().toIso8601String()}).eq('id', roomId).select().single() as Map<String, dynamic>;

      return {'success': true, 'role': 'spectator', 'room': updatedRoom};
    }
  }

  // ХОД В ИГРЕ
  Future<Map<String, dynamic>> makeMove(String roomId, int row, int col) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Получаем текущее состояние комнаты
    final room = await _client.from('rooms').select('*').eq('id', roomId).single() as Map<String, dynamic>;

    final gameState = Map<String, dynamic>.from(room['game_state']);
    final players = List<Map<String, dynamic>>.from(room['players']);

    final player = players.firstWhere((p) => p['id'] == user.id, orElse: () => {});
    if (player.isEmpty) {
      throw Exception('You are not a player in this room');
    }

    // Проверяем возможность хода
    if (!gameState['gameStarted'] || gameState['gameOver'] || gameState['currentPlayer'] != player['playerNumber']) {
      throw Exception('Invalid move');
    }

    final board = List<List<int>>.from(gameState['board'].map((row) => List<int>.from(row)));
    if (row < 0 || row >= 15 || col < 0 || col >= 15 || board[row][col] != 0) {
      throw Exception('Invalid position');
    }

    // Выполняем ход
    board[row][col] = player['playerNumber'] == 1 ? 1 : -1;
    gameState['board'] = board;
    gameState['lastMove'] = {'row': row, 'col': col, 'player': player['playerNumber'], 'playerName': player['username']};

    // Проверяем победу
    if (_checkWin(board, row, col, player['playerNumber'] == 1 ? 1 : -1)) {
      gameState['gameOver'] = true;
      gameState['winner'] = player['playerNumber'];
    } else if (_checkDraw(board)) {
      gameState['gameOver'] = true;
      gameState['winner'] = 0;
    } else {
      gameState['currentPlayer'] = gameState['currentPlayer'] == 1 ? 2 : 1;
    }

    // Сохраняем обновленное состояние
    final updatedRoom = await _client.from('rooms').update({'game_state': gameState, 'updated_at': DateTime.now().toIso8601String()}).eq('id', roomId).select().single() as Map<String, dynamic>;

    return {'success': true, 'room': updatedRoom};
  }

  // ПРОВЕРКА ПОБЕДЫ
  bool _checkWin(List<List<int>> board, int row, int col, int player) {
    const directions = [
      [0, 1], // горизонталь
      [1, 0], // вертикаль
      [1, 1], // диагональ \
      [1, -1], // диагональ /
    ];

    for (final direction in directions) {
      int count = 1;
      final dx = direction[0];
      final dy = direction[1];

      // Проверяем в одном направлении
      for (int i = 1; i <= 4; i++) {
        final newRow = row + dx * i;
        final newCol = col + dy * i;
        if (newRow >= 0 && newRow < 15 && newCol >= 0 && newCol < 15 && board[newRow][newCol] == player) {
          count++;
        } else {
          break;
        }
      }

      // Проверяем в противоположном направлении
      for (int i = 1; i <= 4; i++) {
        final newRow = row - dx * i;
        final newCol = col - dy * i;
        if (newRow >= 0 && newRow < 15 && newCol >= 0 && newCol < 15 && board[newRow][newCol] == player) {
          count++;
        } else {
          break;
        }
      }

      if (count >= 5) return true;
    }

    return false;
  }

  // ПРОВЕРКА НИЧЬЕЙ
  bool _checkDraw(List<List<int>> board) {
    for (final row in board) {
      for (final cell in row) {
        if (cell == 0) return false;
      }
    }
    return true;
  }

  // НАЧАТЬ ИГРУ
  Future<void> startGame(String roomId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final room = await _client.from('rooms').select('*').eq('id', roomId).single() as Map<String, dynamic>;

    final gameState = Map<String, dynamic>.from(room['game_state']);
    gameState['gameStarted'] = true;

    await _client.from('rooms').update({'game_state': gameState, 'updated_at': DateTime.now().toIso8601String()}).eq('id', roomId);
  }

  // СБРОС ИГРЫ
  Future<void> resetGame(String roomId) async {
    final initialBoard = List.generate(15, (_) => List.filled(15, 0));

    await _client
        .from('rooms')
        .update({
          'game_state': {'board': initialBoard, 'currentPlayer': 1, 'gameStarted': true, 'gameOver': false, 'winner': null, 'lastMove': null},
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', roomId);
  }

  // ОТПРАВКА СООБЩЕНИЯ В ЧАТ
  Future<void> sendMessage(String roomId, String message) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _client.from('chat_messages').insert({'room_id': roomId, 'user_id': user.id, 'username': user.userMetadata?['username'] ?? 'Player', 'message': message});
  }

  // ПОКИНУТЬ КОМНАТУ
  Future<void> leaveRoom(String roomId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final room = await _client.from('rooms').select('*').eq('id', roomId).single() as Map<String, dynamic>;

    final players = List<Map<String, dynamic>>.from(room['players']);
    final spectators = List<Map<String, dynamic>>.from(room['spectators']);

    // Удаляем пользователя из игроков или зрителей
    players.removeWhere((p) => p['id'] == user.id);
    spectators.removeWhere((s) => s['id'] == user.id);

    // Если комната пуста, удаляем её
    if (players.isEmpty && spectators.isEmpty) {
      await _client.from('rooms').delete().eq('id', roomId);
    } else {
      await _client.from('rooms').update({'players': players, 'spectators': spectators, 'updated_at': DateTime.now().toIso8601String()}).eq('id', roomId);
    }
  }

  // REAL-TIME ПОДПИСКИ

  // Подписка на список комнат
  Stream<List<Map<String, dynamic>>> watchRooms() {
    return _client.from('rooms').stream(primaryKey: ['id']).order('created_at', ascending: false).map((list) => List<Map<String, dynamic>>.from(list));
  }

  // Подписка на конкретную комнату
  Stream<Map<String, dynamic>> watchRoom(String roomId) {
    return _client.from('rooms').stream(primaryKey: ['id']).eq('id', roomId).map((list) => list.isNotEmpty ? list.first as Map<String, dynamic> : {});
  }

  // Подписка на сообщения чата
  Stream<List<Map<String, dynamic>>> watchChatMessages(String roomId) {
    return _client.from('chat_messages').stream(primaryKey: ['id']).eq('room_id', roomId).order('created_at').map((list) => List<Map<String, dynamic>>.from(list));
  }

  // ДОПОЛНИТЕЛЬНЫЕ МЕТОДЫ

  // Получение профиля пользователя
  Future<Map<String, dynamic>?> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client.from('profiles').select('*').eq('id', user.id).single();

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting profile: $e');
      }
      return null;
    }
  }

  // Обновление профиля
  Future<void> updateProfile(String username) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _client.from('profiles').update({'username': username, 'updated_at': DateTime.now().toIso8601String()}).eq('id', user.id);
  }

  // Получение статистики пользователя
  Future<Map<String, dynamic>?> getUserStats() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client.from('profiles').select('games_played, games_won').eq('id', user.id).single();

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user stats: $e');
      }
      return null;
    }
  }

  // Проверка подключения
  Future<bool> checkConnection() async {
    try {
      await _client.from('rooms').select('count').limit(1);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Connection check failed: $e');
      }
      return false;
    }
  }

  // Очистка подписок
  void dispose() {
    // Supabase client автоматически управляет подписками
    // При необходимости можно добавить очистку кастомных подписок
  }
}
