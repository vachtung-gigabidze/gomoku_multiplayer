import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gomoku_multiplayer/services/supabase_service.dart';

class GameProvider with ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();

  // Состояние аутентификации
  AuthState _authState = AuthState.initial;
  String? _email;
  String? _username;

  // Состояние игры
  String? _roomId;
  String _role = '';
  int _playerNumber = 0;
  List<Map<String, dynamic>> _rooms = [];
  Map<String, dynamic>? _currentRoom;
  List<List<int>> _board = List.generate(15, (_) => List.filled(15, 0));
  bool _gameStarted = false;
  bool _gameOver = false;
  int _currentPlayer = 1;
  int? _winner;
  List<Map<String, dynamic>> _chatMessages = [];
  bool _isLoading = false;
  String? _errorMessage;
  // Таймер для автоперехода после успешной аутентификации
  Timer? _successTimer;

  // Getters
  String? get errorMessage => _errorMessage;
  AuthState get authState => _authState;
  String? get email => _email;
  String? get username => _username;
  String? get roomId => _roomId;
  String get role => _role;
  int get playerNumber => _playerNumber;
  List<Map<String, dynamic>> get rooms => _rooms;
  Map<String, dynamic>? get currentRoom => _currentRoom;
  List<List<int>> get board => _board;
  bool get gameStarted => _gameStarted;
  bool get gameOver => _gameOver;
  int get currentPlayer => _currentPlayer;
  int? get winner => _winner;
  List<Map<String, dynamic>> get chatMessages => _chatMessages;
  bool get isLoading => _isLoading;
  User? get currentUser => _supabase.currentUser;
  bool get isAuthenticated => _supabase.currentUser != null;

  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _userStats;
  bool _isProfileLoading = false;

  // Добавляем геттеры:
  Map<String, dynamic>? get userProfile => _userProfile;
  Map<String, dynamic>? get userStats => _userStats;
  bool get isProfileLoading => _isProfileLoading;

  // Аутентификация по OTP
  Future<void> sendOTP(String email, {String? username}) async {
    _setLoading(true);
    try {
      _email = email;
      _username = username;

      if (username != null) {
        // Регистрация
        await _supabase.signUpWithOTP(email, username);
      } else {
        // Вход
        await _supabase.signInWithOTP(email);
      }

      _authState = AuthState.otpSent;
      _safeNotifyListeners();
    } catch (e) {
      _authState = AuthState.error;
      _safeNotifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Подтверждение OTP
  Future<void> verifyOTP(String token) async {
    if (_email == null) throw Exception('Email not set');

    _setLoading(true);
    try {
      await _supabase.verifyOTP(_email!, token);
      _authState = AuthState.authenticated;
      _safeNotifyListeners();

      // Автоматический переход через 2 секунды
      _successTimer = Timer(const Duration(seconds: 2), () {
        _authState = AuthState.initial;
        _safeNotifyListeners();
      });
    } catch (e) {
      _authState = AuthState.error;
      _safeNotifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Повторная отправка OTP
  Future<void> resendOTP() async {
    if (_email == null) throw Exception('Email not set');

    _setLoading(true);
    try {
      await _supabase.resendOTP(_email!);
      _safeNotifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Выход
  Future<void> signOut() async {
    await _supabase.signOut();
    _resetAuthState();
    _resetRoomState();
    _safeNotifyListeners();
  }

  // Сброс состояния аутентификации
  void resetAuthState() {
    _resetAuthState();
    _safeNotifyListeners();
  }

  void _resetAuthState() {
    _authState = AuthState.initial;
    _email = null;
    _username = null;
    _successTimer?.cancel();
    _successTimer = null;
    _errorMessage = null;
  }

  // Игровые методы
  Future<void> loadRooms() async {
    _setLoading(true);
    try {
      final rooms = await _supabase.getRooms();
      _updateRooms(rooms);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading rooms: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createRoom(String roomName) async {
    _setLoading(true);
    try {
      final result = await _supabase.createRoom(roomName);
      _updateRoomState(result);
    } catch (e) {
      if (kDebugMode) {
        print('Error creating room: $e');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> joinRoom(String roomId) async {
    _setLoading(true);
    try {
      final result = await _supabase.joinRoom(roomId);
      _updateRoomState(result['room']);
      _role = result['role'];
      _playerNumber = result['playerNumber'] ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('Error joining room: $e');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> makeMove(int row, int col) async {
    if (_roomId == null) return;

    try {
      final result = await _supabase.makeMove(_roomId!, row, col);
      _updateRoomState(result['room']);
    } catch (e) {
      if (kDebugMode) {
        print('Error making move: $e');
      }
      rethrow;
    }
  }

  Future<void> startGame() async {
    if (_roomId == null) return;

    try {
      await _supabase.startGame(_roomId!);
    } catch (e) {
      if (kDebugMode) {
        print('Error starting game: $e');
      }
      rethrow;
    }
  }

  Future<void> resetGame() async {
    if (_roomId == null) return;

    try {
      await _supabase.resetGame(_roomId!);
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting game: $e');
      }
      rethrow;
    }
  }

  Future<void> sendMessage(String message) async {
    if (_roomId == null) return;

    try {
      await _supabase.sendMessage(_roomId!, message);
    } catch (e) {
      if (kDebugMode) {
        print('Error sending message: $e');
      }
      rethrow;
    }
  }

  Future<void> leaveRoom() async {
    if (_roomId == null) return;

    try {
      await _supabase.leaveRoom(_roomId!);
      _resetRoomState();
    } catch (e) {
      if (kDebugMode) {
        print('Error leaving room: $e');
      }
    }
  }

  // Real-time подписки с логированием
  void subscribeToRooms() {
    print('Subscribing to rooms updates...');
    _supabase.watchRooms().listen(
      (rooms) {
        print('Rooms updated: ${rooms.length} rooms');
        _updateRooms(rooms);
      },
      onError: (error) {
        print('Error in rooms subscription: $error');
      },
    );
  }

  void subscribeToRoom(String roomId) {
    print('Subscribing to room: $roomId');
    _supabase
        .watchRoom(roomId)
        .listen(
          (room) {
            if (room.isNotEmpty) {
              print('Room updated: ${room['name']}');
              _updateRoomState(room);
            } else {
              print('Room $roomId not found in subscription');
            }
          },
          onError: (error) {
            print('Error in room subscription: $error');
          },
        );
  }

  void subscribeToChat(String roomId) {
    print('Subscribing to chat for room: $roomId');
    _supabase
        .watchChatMessages(roomId)
        .listen(
          (messages) {
            print('Chat updated: ${messages.length} messages');
            _updateChatMessages(messages);
          },
          onError: (error) {
            print('Error in chat subscription: $error');
          },
        );
  }

  // Вспомогательные методы для обновления состояния
  void _updateRoomState(Map<String, dynamic> room) {
    _roomId = room['id'];
    _currentRoom = room;
    _updateGameState(room['game_state']);
    _safeNotifyListeners();
  }

  void _updateGameState(Map<String, dynamic> gameState) {
    _board = List<List<int>>.from(gameState['board'].map((row) => List<int>.from(row)));
    _gameStarted = gameState['gameStarted'] ?? false;
    _gameOver = gameState['gameOver'] ?? false;
    _currentPlayer = gameState['currentPlayer'] ?? 1;
    _winner = gameState['winner'];
  }

  void _updateRooms(List<Map<String, dynamic>> rooms) {
    _rooms = rooms;
    _safeNotifyListeners();
  }

  void _updateChatMessages(List<Map<String, dynamic>> messages) {
    _chatMessages = messages;
    _safeNotifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    _safeNotifyListeners();
  }

  void _resetRoomState() {
    _roomId = null;
    _currentRoom = null;
    _board = List.generate(15, (_) => List.filled(15, 0));
    _gameStarted = false;
    _gameOver = false;
    _currentPlayer = 1;
    _winner = null;
    _chatMessages.clear();
    _role = '';
    _playerNumber = 0;
  }

  // Проверка, может ли пользователь сделать ход
  bool canMakeMove(int row, int col) {
    if (!_gameStarted || _gameOver) return false;
    if (_role != 'player') return false;
    if (_currentPlayer != _playerNumber) return false;
    if (row < 0 || row >= 15 || col < 0 || col >= 15) return false;
    if (_board[row][col] != 0) return false;

    return true;
  }

  // Получение информации о текущем игроке
  String get currentPlayerName {
    if (!_gameStarted) return 'Waiting to start...';
    if (_gameOver) {
      if (_winner == 0) return 'Game Over: Draw!';
      return 'Game Over: Player $_winner wins!';
    }
    return 'Current player: ${_currentPlayer == 1 ? 'Black' : 'White'}';
  }

  // Получение информации о роли пользователя
  String get playerInfo {
    if (_role == 'player') {
      return 'You are Player $_playerNumber (${_playerNumber == 1 ? 'Black' : 'White'})';
    } else if (_role == 'spectator') {
      return 'You are spectating';
    }
    return 'Not in game';
  }

  // Проверка, заполнена ли комната
  bool get isRoomFull {
    if (_currentRoom == null) return false;
    final players = List<Map<String, dynamic>>.from(_currentRoom!['players'] ?? []);
    return players.length >= 2;
  }

  // Проверка, может ли пользователь начать игру
  bool get canStartGame {
    if (_currentRoom == null) return false;
    if (_gameStarted) return false;

    final players = List<Map<String, dynamic>>.from(_currentRoom!['players'] ?? []);
    final isPlayer = players.any((player) => player['id'] == _supabase.currentUser?.id);

    return players.length == 2 && isPlayer;
  }

  // Безопасный вызов notifyListeners
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // Проверка текущей сессии
  // Future<void> checkAuthStatus() async {
  //   try {
  //     final user = await _supabase.getCurrentUser();
  //     if (user != null) {
  //       _authState = AuthState.authenticated;
  //       _safeNotifyListeners();
  //     }
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('Auth check error: $e');
  //     }
  //   }
  // }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _successTimer?.cancel();
    super.dispose();
  }

  Future<void> updateProfile({required String username, String? avatarUrl}) async {
    _setProfileLoading(true);
    _errorMessage = null;

    try {
      print('GameProvider: Updating profile with username: $username');

      await _supabase.updateProfile(username: username, avatarUrl: avatarUrl);

      // Перезагружаем профиль чтобы получить обновленные данные
      await loadUserProfile();

      _safeNotifyListeners();

      print('GameProvider: Profile updated successfully');
    } catch (e) {
      // Сохраняем имя пользователя локально даже если обновление не удалось
      _username = username;
      _errorMessage = 'Profile update failed: ${e.toString()}';
      print('GameProvider: Error updating profile: $e');
      _safeNotifyListeners();

      // Не бросаем исключение, чтобы пользователь мог продолжить использовать приложение
    } finally {
      _setProfileLoading(false);
    }
  }

  // Исправленный метод loadUserProfile
  Future<void> loadUserProfile() async {
    _setProfileLoading(true);
    try {
      print('GameProvider: Loading user profile...');

      _userProfile = await _supabase.getProfile();
      _userStats = await _supabase.getUserStats();

      // Обновляем локальное имя пользователя
      if (_userProfile != null && _userProfile!['username'] != null) {
        _username = _userProfile!['username'];
      }

      print('GameProvider: User profile loaded: $_userProfile');
      print('GameProvider: User stats loaded: $_userStats');

      _safeNotifyListeners();
    } catch (e) {
      print('GameProvider: Error loading user profile: $e');
      _errorMessage = 'Failed to load profile: ${e.toString()}';
      _safeNotifyListeners();
    } finally {
      _setProfileLoading(false);
    }
  }

  // Обновление email
  Future<void> updateEmail(String newEmail) async {
    _setProfileLoading(true);
    try {
      await _supabase.updateEmail(newEmail);
      _safeNotifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error updating email: $e');
      }
      rethrow;
    } finally {
      _setProfileLoading(false);
    }
  }

  // Загрузка аватара
  Future<String?> uploadAvatar(File imageFile) async {
    try {
      final avatarUrl = await _supabase.uploadAvatar(imageFile);
      if (avatarUrl != null) {
        // Обновляем профиль с новым аватаром
        await updateProfile(username: _userProfile?['username'] ?? _username ?? 'Player', avatarUrl: avatarUrl);
      }
      return avatarUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading avatar: $e');
      }
      rethrow;
    }
  }

  // Удаление аккаунта
  Future<void> deleteAccount() async {
    _setProfileLoading(true);
    try {
      await _supabase.deleteAccount();
      await signOut();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting account: $e');
      }
      rethrow;
    } finally {
      _setProfileLoading(false);
    }
  }

  // Вспомогательный метод для загрузки профиля
  void _setProfileLoading(bool loading) {
    _isProfileLoading = loading;
    _safeNotifyListeners();
  }

  // Обновляем метод checkAuthStatus для загрузки профиля
  Future<void> checkAuthStatus() async {
    try {
      final user = await _supabase.getCurrentUser();
      if (user != null) {
        _authState = AuthState.authenticated;
        // Загружаем профиль при успешной аутентификации
        await loadUserProfile();
        _safeNotifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Auth check error: $e');
      }
    }
  }
}

// Состояния аутентификации
enum AuthState {
  initial, // Начальное состояние - ввод email
  otpSent, // OTP отправлен - ввод кода
  authenticated, // Успешная аутентификация
  error, // Ошибка аутентификации
}
