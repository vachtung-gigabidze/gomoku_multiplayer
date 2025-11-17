import 'dart:io';

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
          await _createProfile(response.user!.id, username, null);
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
  Future<void> _createProfile(String userId, String username, String? avatarUrl) async {
    try {
      print('Creating new profile for user: $userId');

      final profileData = {'id': userId, 'username': username, 'created_at': DateTime.now().toIso8601String(), 'updated_at': DateTime.now().toIso8601String()};

      if (avatarUrl != null) {
        profileData['avatar_url'] = avatarUrl;
      }

      final response = await _client.from('profiles').insert(profileData).select();

      if (response.isEmpty) {
        throw Exception('Failed to create profile');
      }

      print('Profile created successfully: ${response.first}');
    } catch (e) {
      print('Error creating profile: $e');
      rethrow;
    }
  }

  // СОЗДАНИЕ КОМНАТЫ
  // Future<Map<String, dynamic>> createRoom(String roomName) async {
  //   final user = _client.auth.currentUser;
  //   if (user == null) throw Exception('Not authenticated');

  //   // Инициализируем пустую доску 15x15
  //   final initialBoard = List.generate(15, (_) => List.filled(15, 0));

  //   final response = await _client
  //       .from('rooms')
  //       .insert({
  //         'name': roomName,
  //         'created_by': user.id,
  //         'game_state': {'board': initialBoard, 'currentPlayer': 1, 'gameStarted': false, 'gameOver': false, 'winner': null, 'lastMove': null},
  //         'players': [
  //           {'id': user.id, 'username': user.userMetadata?['username'] ?? 'Player', 'playerNumber': 1, 'joined_at': DateTime.now().toIso8601String()},
  //         ],
  //         'spectators': [],
  //       })
  //       .select()
  //       .single();

  //   return response;
  // }

  // ПОЛУЧЕНИЕ СПИСКА КОМНАТ
  Future<List<Map<String, dynamic>>> getRooms() async {
    final response = await _client.from('rooms').select('*').order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // ПРИСОЕДИНЕНИЕ К КОМНАТЕ
  Future<Map<String, dynamic>> joinRoom(String roomId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    try {
      // Получаем текущую комнату с обработкой ошибок
      final roomResponse = await _client.from('rooms').select('*').eq('id', roomId);

      if (roomResponse.isEmpty) {
        throw Exception('Room not found');
      }

      final room = roomResponse.first as Map<String, dynamic>;
      final players = List<Map<String, dynamic>>.from(room['players'] ?? []);
      final spectators = List<Map<String, dynamic>>.from(room['spectators'] ?? []);

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

        // Обновляем комнату и получаем обновленные данные
        final updateResponse = await _client.from('rooms').update({'players': players, 'updated_at': DateTime.now().toIso8601String()}).eq('id', roomId).select();

        if (updateResponse.isEmpty) {
          throw Exception('Failed to update room');
        }

        final updatedRoom = updateResponse.first as Map<String, dynamic>;

        return {'success': true, 'role': 'player', 'playerNumber': players.length, 'room': updatedRoom};
      } else {
        // Присоединяемся как зритель
        final newSpectator = {'id': user.id, 'username': user.userMetadata?['username'] ?? 'Player', 'joined_at': DateTime.now().toIso8601String()};

        spectators.add(newSpectator);

        // Обновляем комнату и получаем обновленные данные
        final updateResponse = await _client.from('rooms').update({'spectators': spectators, 'updated_at': DateTime.now().toIso8601String()}).eq('id', roomId).select();

        if (updateResponse.isEmpty) {
          throw Exception('Failed to update room');
        }

        final updatedRoom = updateResponse.first as Map<String, dynamic>;

        return {'success': true, 'role': 'spectator', 'room': updatedRoom};
      }
    } catch (e) {
      if (kDebugMode) {
        print('Join room error: $e');
      }
      rethrow;
    }
  }

  // Future<Map<String, dynamic>> joinRoom(String roomId) async {
  //   final user = _client.auth.currentUser;
  //   if (user == null) throw Exception('Not authenticated');

  //   try {
  //     print('=== JOIN ROOM PROCESS START ===');
  //     print('Room: $roomId, User: ${user.id}');

  //     // Метод 1: Пробуем RPC функцию в первую очередь
  //     try {
  //       print('Trying RPC method...');
  //       final rpcResponse = await _client.rpc('join_room', params: {'p_room_id': roomId, 'p_user_id': user.id, 'p_user_name': user.userMetadata?['username'] ?? 'Player'});

  //       print('RPC response: $rpcResponse');

  //       if (rpcResponse != null && rpcResponse['success'] == true) {
  //         // Успешно присоединились через RPC
  //         final roomResponse = await _client.from('rooms').select('*').eq('id', roomId);

  //         if (roomResponse.isNotEmpty) {
  //           final updatedRoom = roomResponse.first as Map<String, dynamic>;
  //           final players = List<Map<String, dynamic>>.from(updatedRoom['players'] ?? []);

  //           final playerNumber = players.firstWhere((p) => p['id'] == user.id, orElse: () => {'playerNumber': players.length})['playerNumber'];

  //           print('✅ Successfully joined room via RPC as player $playerNumber');

  //           return {'success': true, 'role': 'player', 'playerNumber': playerNumber, 'room': updatedRoom};
  //         }
  //       } else if (rpcResponse != null && rpcResponse['error'] != null) {
  //         throw Exception('RPC Error: ${rpcResponse['error']}');
  //       }
  //     } catch (rpcError) {
  //       print('❌ RPC method failed: $rpcError');
  //     }

  //     // Метод 2: Прямое обновление через Supabase
  //     print('Trying direct update method...');
  //     return await _joinRoomDirectUpdate(roomId, user);
  //   } catch (e) {
  //     print('❌ All join methods failed: $e');
  //     rethrow;
  //   } finally {
  //     print('=== JOIN ROOM PROCESS END ===');
  //   }
  // }

  // Прямое обновление комнаты
  Future<Map<String, dynamic>> _joinRoomDirectUpdate(String roomId, User user) async {
    // 1. Получаем текущую комнату
    final roomResponse = await _client.from('rooms').select('*').eq('id', roomId);

    if (roomResponse.isEmpty) {
      throw Exception('Room not found');
    }

    final room = roomResponse.first as Map<String, dynamic>;
    final players = List<Map<String, dynamic>>.from(room['players'] ?? []);
    final gameState = Map<String, dynamic>.from(room['game_state'] ?? {});

    print('Room status - Players: ${players.length}, Game started: ${gameState['gameStarted']}');

    // 2. Проверяем условия присоединения
    if (gameState['gameStarted'] == true) {
      throw Exception('Game already started');
    }

    if (players.length >= 2) {
      throw Exception('Room is full (${players.length}/2)');
    }

    // 3. Проверяем, не присоединен ли уже пользователь
    if (players.any((p) => p['id'] == user.id)) {
      final playerNumber = players.firstWhere((p) => p['id'] == user.id)['playerNumber'];
      print('User already in room as player $playerNumber');
      return {'success': true, 'role': 'player', 'playerNumber': playerNumber, 'room': room};
    }

    // 4. Добавляем нового игрока
    final newPlayer = {'id': user.id, 'username': user.userMetadata?['username'] ?? 'Player', 'playerNumber': players.length + 1, 'joined_at': DateTime.now().toIso8601String()};

    players.add(newPlayer);

    print('Adding new player: ${newPlayer['username']} as player ${players.length}');

    // 5. Обновляем комнату
    final updateResponse = await _client.from('rooms').update({'players': players, 'updated_at': DateTime.now().toIso8601String()}).eq('id', roomId).select();

    if (updateResponse.isEmpty) {
      throw Exception('Failed to update room - RLS policy may be blocking the update');
    }

    final updatedRoom = updateResponse.first as Map<String, dynamic>;
    print('✅ Successfully joined room via direct update as player ${players.length}');

    return {'success': true, 'role': 'player', 'playerNumber': players.length, 'room': updatedRoom};
  }

  // ХОД В ИГРЕ
  // Future<Map<String, dynamic>> makeMove(String roomId, int row, int col) async {
  //   final user = _client.auth.currentUser;
  //   if (user == null) throw Exception('Not authenticated');

  //   // Получаем текущее состояние комнаты
  //   final room = await _client.from('rooms').select('*').eq('id', roomId).single() as Map<String, dynamic>;

  //   final gameState = Map<String, dynamic>.from(room['game_state']);
  //   final players = List<Map<String, dynamic>>.from(room['players']);

  //   final player = players.firstWhere((p) => p['id'] == user.id, orElse: () => {});
  //   if (player.isEmpty) {
  //     throw Exception('You are not a player in this room');
  //   }

  //   // Проверяем возможность хода
  //   if (!gameState['gameStarted'] || gameState['gameOver'] || gameState['currentPlayer'] != player['playerNumber']) {
  //     throw Exception('Invalid move');
  //   }

  //   final board = List<List<int>>.from(gameState['board'].map((row) => List<int>.from(row)));
  //   if (row < 0 || row >= 15 || col < 0 || col >= 15 || board[row][col] != 0) {
  //     throw Exception('Invalid position');
  //   }

  //   // Выполняем ход
  //   board[row][col] = player['playerNumber'] == 1 ? 1 : -1;
  //   gameState['board'] = board;
  //   gameState['lastMove'] = {'row': row, 'col': col, 'player': player['playerNumber'], 'playerName': player['username']};

  //   // Проверяем победу
  //   if (_checkWin(board, row, col, player['playerNumber'] == 1 ? 1 : -1)) {
  //     gameState['gameOver'] = true;
  //     gameState['winner'] = player['playerNumber'];
  //   } else if (_checkDraw(board)) {
  //     gameState['gameOver'] = true;
  //     gameState['winner'] = 0;
  //   } else {
  //     gameState['currentPlayer'] = gameState['currentPlayer'] == 1 ? 2 : 1;
  //   }

  //   // Сохраняем обновленное состояние
  //   final updatedRoom = await _client.from('rooms').update({'game_state': gameState, 'updated_at': DateTime.now().toIso8601String()}).eq('id', roomId).select().single() as Map<String, dynamic>;

  //   return {'success': true, 'room': updatedRoom};
  // }

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
  // Future<void> startGame(String roomId) async {
  //   final user = _client.auth.currentUser;
  //   if (user == null) throw Exception('Not authenticated');

  //   final room = await _client.from('rooms').select('*').eq('id', roomId).single() as Map<String, dynamic>;

  //   final gameState = Map<String, dynamic>.from(room['game_state']);
  //   gameState['gameStarted'] = true;

  //   await _client.from('rooms').update({'game_state': gameState, 'updated_at': DateTime.now().toIso8601String()}).eq('id', roomId);
  // }

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
  // Future<void> leaveRoom(String roomId) async {
  //   final user = _client.auth.currentUser;
  //   if (user == null) return;

  //   final room = await _client.from('rooms').select('*').eq('id', roomId).single() as Map<String, dynamic>;

  //   final players = List<Map<String, dynamic>>.from(room['players']);
  //   final spectators = List<Map<String, dynamic>>.from(room['spectators']);

  //   // Удаляем пользователя из игроков или зрителей
  //   players.removeWhere((p) => p['id'] == user.id);
  //   spectators.removeWhere((s) => s['id'] == user.id);

  //   // Если комната пуста, удаляем её
  //   if (players.isEmpty && spectators.isEmpty) {
  //     await _client.from('rooms').delete().eq('id', roomId);
  //   } else {
  //     await _client.from('rooms').update({'players': players, 'spectators': spectators, 'updated_at': DateTime.now().toIso8601String()}).eq('id', roomId);
  //   }
  // }

  // REAL-TIME ПОДПИСКИ

  // Polling методы вместо real-time
  Stream<List<Map<String, dynamic>>> watchRooms() {
    // Для бесплатного тарифа используем polling каждые 5 секунд
    return Stream.periodic(const Duration(seconds: 5)).asyncMap((_) => getRooms()).asBroadcastStream();
  }

  Stream<Map<String, dynamic>> watchRoom(String roomId) {
    // Polling для конкретной комнаты каждые 2 секунды
    return Stream.periodic(const Duration(seconds: 2)).asyncMap((_) => _getRoomById(roomId)).where((room) => room.isNotEmpty).asBroadcastStream();
  }

  Stream<List<Map<String, dynamic>>> watchChatMessages(String roomId) {
    // Polling для чата каждые 1 секунду
    return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) => _getChatMessages(roomId)).asBroadcastStream();
  }

  // ДОПОЛНИТЕЛЬНЫЕ МЕТОДЫ
  // Вспомогательные методы для polling
  Future<Map<String, dynamic>> _getRoomById(String roomId) async {
    try {
      final response = await _client.from('rooms').select('*').eq('id', roomId);

      return response.isEmpty ? {} : response.first;
    } catch (e) {
      print('Error getting room by id: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _getChatMessages(String roomId) async {
    try {
      final response = await _client.from('chat_messages').select('*').eq('room_id', roomId).order('created_at');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting chat messages: $e');
      return [];
    }
  }
  // // Получение профиля пользователя
  // Future<Map<String, dynamic>?> getProfile() async {
  //   final user = _client.auth.currentUser;
  //   if (user == null) return null;

  //   try {
  //     final response = await _client.from('profiles').select('*').eq('id', user.id).single();

  //     return response;
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('Error getting profile: $e');
  //     }
  //     return null;
  //   }
  // }

  // Обновление профиля
  // Future<void> updateProfile(String username) async {
  //   final user = _client.auth.currentUser;
  //   if (user == null) throw Exception('Not authenticated');

  //   await _client.from('profiles').update({'username': username, 'updated_at': DateTime.now().toIso8601String()}).eq('id', user.id);
  // }

  // Получение статистики пользователя
  // Future<Map<String, dynamic>?> getUserStats() async {
  //   final user = _client.auth.currentUser;
  //   if (user == null) return null;

  //   try {
  //     final response = await _client.from('profiles').select('games_played, games_won').eq('id', user.id).single();

  //     return response;
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('Error getting user stats: $e');
  //     }
  //     return null;
  //   }
  // }

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

  // Получение профиля пользователя
  Future<Map<String, dynamic>?> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      print('Getting profile via RPC for user: ${user.id}');

      // Используем RPC функцию для получения профиля
      final response = await _client.rpc('get_user_profile', params: {'p_user_id': user.id});

      if (response == null || response['error'] != null) {
        print('RPC get profile failed: ${response?['error']}');
        return await _getProfileDirect(user.id);
      }

      print('Profile retrieved successfully via RPC');
      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('Error getting profile via RPC: $e');
      return await _getProfileDirect(user.id);
    }
  }

  Future<Map<String, dynamic>?> _getProfileDirect(String userId) async {
    try {
      print('Trying direct profile retrieval...');

      final response = await _client.from('profiles').select('*').eq('id', userId);

      if (response.isEmpty) {
        print('Profile not found via direct method');
        return null;
      }

      print('Profile retrieved successfully via direct method');
      return response.first;
    } catch (e) {
      print('Direct profile retrieval also failed: $e');
      return null;
    }
  }

  // Метод для создания профиля по умолчанию
  Future<Map<String, dynamic>> _createDefaultProfile(String userId) async {
    try {
      final defaultProfile = {'id': userId, 'username': 'Player', 'games_played': 0, 'games_won': 0, 'created_at': DateTime.now().toIso8601String(), 'updated_at': DateTime.now().toIso8601String()};

      await _client.from('profiles').insert(defaultProfile);
      return defaultProfile;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating default profile: $e');
      }
      // Возвращаем базовый профиль даже при ошибке
      return {'id': userId, 'username': 'Player', 'games_played': 0, 'games_won': 0};
    }
  }
  // Future<Map<String, dynamic>?> getProfile() async {
  //   final user = _client.auth.currentUser;
  //   if (user == null) return null;

  //   try {
  //     final response = await _client.from('profiles').select('*').eq('id', user.id).single();

  //     return response;
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('Error getting profile: $e');
  //     }
  //     return null;
  //   }
  // }

  // Обновление профиля
  Future<void> updateProfile({required String username, String? avatarUrl}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    try {
      print('Updating profile via RPC for user: ${user.id}');
      print('New username: $username, avatarUrl: $avatarUrl');

      // Используем RPC функцию для обновления профиля
      final response = await _client.rpc('create_or_update_profile', params: {'p_user_id': user.id, 'p_username': username, 'p_avatar_url': avatarUrl});

      print('RPC response: $response');

      if (response == null || response['success'] != true) {
        throw Exception('Failed to update profile via RPC: ${response?['error']}');
      }

      print('Profile updated successfully via RPC');
    } catch (e) {
      print('Error updating profile via RPC: $e');

      // Если RPC не сработал, пробуем обычный метод как запасной вариант
      await _updateProfileDirect(user.id, username, avatarUrl);
    }
  }

  Future<void> _updateProfileDirect(String userId, String username, String? avatarUrl) async {
    try {
      print('Trying direct profile update...');

      final updateData = {'username': username, 'updated_at': DateTime.now().toIso8601String()};

      if (avatarUrl != null) {
        updateData['avatar_url'] = avatarUrl;
      }

      // Пробуем обновить профиль напрямую
      final response = await _client.from('profiles').update(updateData).eq('id', userId).select();

      if (response.isEmpty) {
        print('Profile not found, creating new one...');
        // Если профиль не существует, создаем его
        await _createProfileDirect(userId, username, avatarUrl);
      } else {
        print('Profile updated successfully via direct method');
      }
    } catch (e) {
      print('Direct profile update also failed: $e');
      rethrow;
    }
  } // Прямое создание профиля

  Future<void> _createProfileDirect(String userId, String username, String? avatarUrl) async {
    try {
      final profileData = {'id': userId, 'username': username, 'created_at': DateTime.now().toIso8601String(), 'updated_at': DateTime.now().toIso8601String()};

      if (avatarUrl != null) {
        profileData['avatar_url'] = avatarUrl;
      }

      final response = await _client.from('profiles').insert(profileData).select();

      if (response.isEmpty) {
        throw Exception('Failed to create profile via direct method');
      }

      print('Profile created successfully via direct method');
    } catch (e) {
      print('Error creating profile via direct method: $e');
      rethrow;
    }
  }

  // Обновление email
  Future<void> updateEmail(String newEmail) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _client.auth.updateUser(UserAttributes(email: newEmail));
  }

  // Получение статистики игрока
  Future<Map<String, dynamic>> getUserStats() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    try {
      // Получаем профиль со статистикой
      final profile = await _client.from('profiles').select('games_played, games_won, username, avatar_url').eq('id', user.id).single();

      return profile;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user stats: $e');
      }
      return {'games_played': 0, 'games_won': 0, 'username': 'Player', 'avatar_url': null};
    }
  }

  // Загрузка аватара
  Future<String?> uploadAvatar(File imageFile) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    try {
      final fileExtension = imageFile.path.split('.').last;
      final fileName = 'avatars/${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      // Загружаем файл в Supabase Storage
      await _client.storage.from('avatars').upload(fileName, imageFile);

      // Получаем публичный URL
      final String publicUrl = _client.storage.from('avatars').getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading avatar: $e');
      }
      return null;
    }
  }

  // Удаление аккаунта
  Future<void> deleteAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Сначала удаляем профиль
    await _client.from('profiles').delete().eq('id', user.id);

    // Затем удаляем пользователя из auth
    await _client.auth.admin.deleteUser(user.id);
  }

  Future<Map<String, dynamic>> createRoom(String roomName) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    try {
      // Инициализируем пустую доску 15x15
      final initialBoard = List.generate(15, (_) => List.filled(15, 0));

      final response = await _client.from('rooms').insert({
        'name': roomName,
        'created_by': user.id,
        'game_state': {'board': initialBoard, 'currentPlayer': 1, 'gameStarted': false, 'gameOver': false, 'winner': null, 'lastMove': null},
        'players': [
          {'id': user.id, 'username': user.userMetadata?['username'] ?? 'Player', 'playerNumber': 1, 'joined_at': DateTime.now().toIso8601String()},
        ],
        'spectators': [],
      }).select();

      if (response.isEmpty) {
        throw Exception('Failed to create room');
      }

      return response.first;
    } catch (e) {
      if (kDebugMode) {
        print('Create room error: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> makeMove(String roomId, int row, int col) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    try {
      // Получаем текущее состояние комнаты
      final roomResponse = await _client.from('rooms').select('*').eq('id', roomId);

      if (roomResponse.isEmpty) {
        throw Exception('Room not found');
      }

      final room = roomResponse.first as Map<String, dynamic>;
      final gameState = Map<String, dynamic>.from(room['game_state'] ?? {});
      final players = List<Map<String, dynamic>>.from(room['players'] ?? []);

      final player = players.firstWhere((p) => p['id'] == user.id, orElse: () => {});
      if (player.isEmpty) {
        throw Exception('You are not a player in this room');
      }

      // Проверяем возможность хода
      if (!gameState['gameStarted'] || gameState['gameOver'] || gameState['currentPlayer'] != player['playerNumber']) {
        throw Exception('Invalid move');
      }

      final board = List<List<int>>.from((gameState['board'] as List).map((row) => List<int>.from(row)));

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
      final updateResponse = await _client.from('rooms').update({'game_state': gameState, 'updated_at': DateTime.now().toIso8601String()}).eq('id', roomId).select();

      if (updateResponse.isEmpty) {
        throw Exception('Failed to update game state');
      }

      final updatedRoom = updateResponse.first as Map<String, dynamic>;

      return {'success': true, 'room': updatedRoom};
    } catch (e) {
      if (kDebugMode) {
        print('Make move error: $e');
      }
      rethrow;
    }
  }

  Future<void> startGame(String roomId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    try {
      final roomResponse = await _client.from('rooms').select('*').eq('id', roomId);

      if (roomResponse.isEmpty) {
        throw Exception('Room not found');
      }

      final room = roomResponse.first as Map<String, dynamic>;
      final gameState = Map<String, dynamic>.from(room['game_state'] ?? {});
      gameState['gameStarted'] = true;

      await _client.from('rooms').update({'game_state': gameState, 'updated_at': DateTime.now().toIso8601String()}).eq('id', roomId);
    } catch (e) {
      if (kDebugMode) {
        print('Start game error: $e');
      }
      rethrow;
    }
  }

  // Исправленный метод leaveRoom
  Future<void> leaveRoom(String roomId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      print('Leaving room: $roomId');

      // Получаем текущую комнату
      final roomResponse = await _client.from('rooms').select('*').eq('id', roomId);

      if (roomResponse.isEmpty) {
        print('Room $roomId not found, already deleted?');
        return; // Комната уже удалена
      }

      final room = roomResponse.first as Map<String, dynamic>;
      final players = List<Map<String, dynamic>>.from(room['players'] ?? []);
      final spectators = List<Map<String, dynamic>>.from(room['spectators'] ?? []);

      print('Current players: ${players.length}, spectators: ${spectators.length}');

      // Удаляем пользователя из игроков
      final initialPlayerCount = players.length;
      players.removeWhere((p) => p['id'] == user.id);

      // Удаляем пользователя из зрителей
      spectators.removeWhere((s) => s['id'] == user.id);

      print('After removal - players: ${players.length}, spectators: ${spectators.length}');

      // Если пользователь был удален из игроков, перенумеровываем оставшихся
      if (players.length < initialPlayerCount) {
        for (int i = 0; i < players.length; i++) {
          players[i]['playerNumber'] = i + 1;
        }
      }

      // Если комната пуста, удаляем её
      if (players.isEmpty && spectators.isEmpty) {
        print('Room is empty, deleting...');
        await _client.from('rooms').delete().eq('id', roomId);
        print('Room deleted successfully');
      } else {
        // Обновляем комнату с новыми списками
        print('Updating room with new player/spectator lists...');
        final updateResponse = await _client.from('rooms').update({'players': players, 'spectators': spectators, 'updated_at': DateTime.now().toIso8601String()}).eq('id', roomId).select();

        if (updateResponse.isEmpty) {
          print('Room update failed - trying alternative method...');
          // Альтернативный метод - используем RPC
          await _leaveRoomAlternative(roomId, user.id);
        } else {
          print('Room updated successfully');
        }
      }
    } catch (e) {
      print('Leave room error details: $e');
      // Не бросаем исключение, так как выход из комнаты должен работать всегда
    }
  }

  Future<void> _leaveRoomAlternative(String roomId, String userId) async {
    try {
      print('Trying alternative leave method via RPC...');

      // Создаем RPC функцию для выхода из комнаты
      await _client.rpc('leave_room', params: {'p_room_id': roomId, 'p_user_id': userId});

      print('Alternative leave method successful');
    } catch (e) {
      print('Alternative leave method also failed: $e');
      // Игнорируем ошибку, так как это альтернативный метод
    }
  }
}
