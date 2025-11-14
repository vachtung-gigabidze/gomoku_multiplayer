import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:convert';

class GameProvider with ChangeNotifier {
  io.Socket? _socket;
  String _serverUrl = 'http://localhost:3000';

  // Состояние
  String? _playerId;
  String? _roomId;
  String? _username;
  String _role = '';
  int _playerNumber = 0;

  List<dynamic> _rooms = [];
  Map<String, dynamic>? _currentRoom;
  List<List<int>> _board = List.generate(15, (_) => List.filled(15, 0));
  bool _gameStarted = false;
  bool _gameOver = false;
  int _currentPlayer = 1;
  int? _winner;
  List<dynamic> _chatMessages = [];
  String _connectionStatus = 'Disconnected';

  // Getters
  String? get playerId => _playerId;
  String? get roomId => _roomId;
  String? get username => _username;
  String get role => _role;
  int get playerNumber => _playerNumber;
  List<dynamic> get rooms => _rooms;
  Map<String, dynamic>? get currentRoom => _currentRoom;
  List<List<int>> get board => _board;
  bool get gameStarted => _gameStarted;
  bool get gameOver => _gameOver;
  int get currentPlayer => _currentPlayer;
  int? get winner => _winner;
  List<dynamic> get chatMessages => _chatMessages;
  String get connectionStatus => _connectionStatus;

  // Инициализация сокета
  void initSocket() {
    try {
      _socket = io.io(_serverUrl, {
        'transports': ['websocket'],
        'autoConnect': true,
      });

      _socket!.on('connect', (_) {
        _connectionStatus = 'Connected';
        notifyListeners();
      });

      _socket!.on('disconnect', (_) {
        _connectionStatus = 'Disconnected';
        notifyListeners();
      });

      _socket!.on('room_created', (data) {
        _handleRoomCreated(data);
      });

      _socket!.on('joined_room', (data) {
        _handleJoinedRoom(data);
      });

      _socket!.on('room_update', (data) {
        _handleRoomUpdate(data);
      });

      _socket!.on('game_state', (data) {
        _handleGameState(data);
      });

      _socket!.on('chat_message', (data) {
        _handleChatMessage(data);
      });

      _socket!.on('chat_history', (data) {
        _handleChatHistory(data);
      });

      _socket!.on('move_result', (data) {
        _handleMoveResult(data);
      });

      _socket!.on('error', (data) {
        _handleError(data);
      });
    } catch (e) {
      if (kDebugMode) {
        print('Socket initialization error: $e');
      }
    }
  }

  void setUsername(String username) {
    _username = username;
    notifyListeners();
  }

  void setServerUrl(String url) {
    _serverUrl = url;
    notifyListeners();
  }

  // Создание комнаты
  void createRoom(String roomName) {
    if (_socket == null || _username == null) return;

    _socket!.emit('create_room', {'roomName': roomName, 'username': _username});
  }

  // Присоединение к комнате
  void joinRoom(String roomId) {
    if (_socket == null || _username == null) return;

    _socket!.emit('join_room', {'roomId': roomId, 'username': _username});
  }

  // Ход
  void makeMove(int row, int col) {
    if (_socket == null || _roomId == null || _playerId == null) return;

    _socket!.emit('make_move', {'roomId': _roomId, 'playerId': _playerId, 'row': row, 'col': col});
  }

  // Начать игру
  void startGame() {
    if (_socket == null || _roomId == null) return;

    _socket!.emit('start_game', {'roomId': _roomId});
  }

  // Сброс игры
  void resetGame() {
    if (_socket == null || _roomId == null) return;

    _socket!.emit('reset_game', {'roomId': _roomId});
  }

  // Отправка сообщения
  void sendMessage(String message) {
    if (_socket == null || _roomId == null) return;

    _socket!.emit('send_message', {'roomId': _roomId, 'message': message});
  }

  // Выход из комнаты
  void leaveRoom() {
    if (_socket == null || _roomId == null) return;

    _socket!.emit('leave_room', {'roomId': _roomId});

    _resetRoomState();
  }

  // Обработчики событий
  void _handleRoomCreated(dynamic data) {
    _playerId = data['playerId'];
    _roomId = data['roomId'];
    _role = data['role'];
    _playerNumber = data['playerNumber'] ?? 0;
    _currentRoom = Map<String, dynamic>.from(data['roomInfo']);
    notifyListeners();
  }

  void _handleJoinedRoom(dynamic data) {
    _playerId = data['playerId'];
    _roomId = data['roomId'];
    _role = data['role'];
    _playerNumber = data['playerNumber'] ?? 0;
    _currentRoom = Map<String, dynamic>.from(data['roomInfo']);
    notifyListeners();
  }

  void _handleRoomUpdate(dynamic data) {
    _currentRoom = Map<String, dynamic>.from(data);
    notifyListeners();
  }

  void _handleGameState(dynamic data) {
    _board = List<List<int>>.from(data['board'].map((row) => List<int>.from(row)));
    _gameStarted = data['gameStarted'];
    _gameOver = data['gameOver'];
    _currentPlayer = data['currentPlayer'];
    _winner = data['winner'];
    notifyListeners();
  }

  void _handleChatMessage(dynamic data) {
    _chatMessages.add(data);
    notifyListeners();
  }

  void _handleChatHistory(dynamic data) {
    _chatMessages = List<dynamic>.from(data);
    notifyListeners();
  }

  void _handleMoveResult(dynamic data) {
    if (!data['success']) {
      // Показать ошибку
      if (kDebugMode) {
        print('Move error: ${data['message']}');
      }
    }
  }

  void _handleError(dynamic data) {
    if (kDebugMode) {
      print('Error: $data');
    }
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
    notifyListeners();
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}
