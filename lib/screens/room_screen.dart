import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gomoku_multiplayer/providers/game_provider.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isMounted = true;
  bool _isSubscribed = false;

  @override
  void initState() {
    super.initState();
    _initializeSubscriptions();
  }

  void _initializeSubscriptions() async {
    // Ждем завершения build перед подпиской
    await Future.delayed(Duration.zero);

    if (!_isMounted) return;

    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.roomId != null) {
      print('Initializing real-time subscriptions for room: ${gameProvider.roomId}');

      // Подписываемся на обновления комнаты
      gameProvider.subscribeToRoom(gameProvider.roomId!);

      // Подписываемся на сообщения чата
      gameProvider.subscribeToChat(gameProvider.roomId!);

      setState(() {
        _isSubscribed = true;
      });

      print('Real-time subscriptions initialized successfully');
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    gameProvider.sendMessage(message);

    _messageController.clear();
  }

  void _startGame() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    gameProvider.startGame();
  }

  void _resetGame() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    gameProvider.resetGame();
  }

  void _makeMove(int row, int col) {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.canMakeMove(row, col)) {
      gameProvider.makeMove(row, col);
    }
  }

  Widget _buildStone(int value) {
    if (value == 0) return const SizedBox.shrink();

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: value == 1 ? Colors.black : Colors.white,
        shape: BoxShape.circle,
        border: value == -1 ? Border.all(color: Colors.black) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 2, offset: const Offset(1, 1))],
      ),
    );
  }

  Widget _buildGameBoard(GameProvider gameProvider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Game Info
          _buildGameInfo(gameProvider),

          const SizedBox(height: 20),

          // Game Board
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.brown, width: 2),
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFFDEB887), // Цвет дерева для доски
              ),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 15),
                itemCount: 225,
                itemBuilder: (context, index) {
                  final row = index ~/ 15;
                  final col = index % 15;
                  final cellValue = gameProvider.board[row][col];

                  return GestureDetector(
                    onTap: () => _makeMove(row, col),
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.brown.shade300)),
                      child: Center(child: _buildStone(cellValue)),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Game Controls
          _buildGameControls(gameProvider),
        ],
      ),
    );
  }

  Widget _buildGameInfo(GameProvider gameProvider) {
    String status = '';
    Color statusColor = Colors.blue;

    if (!gameProvider.gameStarted) {
      status = 'Waiting for players to start...';
      statusColor = Colors.orange;
    } else if (gameProvider.gameOver) {
      if (gameProvider.winner == 0) {
        status = 'Game Over: Draw!';
        statusColor = Colors.grey;
      } else {
        status = 'Game Over: Player ${gameProvider.winner} wins!';
        statusColor = Colors.green;
      }
    } else {
      status = 'Current player: ${gameProvider.currentPlayer == 1 ? 'Black ⚫' : 'White ⚪'}';
      statusColor = Colors.blue;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              status,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor),
            ),
            const SizedBox(height: 8),

            // Информация об игроках
            if (gameProvider.currentRoom != null) _buildPlayersInfo(gameProvider),

            // Информация о роли пользователя
            const SizedBox(height: 8),
            Text(
              gameProvider.playerInfo,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersInfo(GameProvider gameProvider) {
    final room = gameProvider.currentRoom;
    if (room == null) return const SizedBox.shrink();

    final players = List<Map<String, dynamic>>.from(room['players'] ?? []);

    return Column(
      children: players.map((player) {
        final isCurrentPlayer = gameProvider.gameStarted && !gameProvider.gameOver && gameProvider.currentPlayer == player['playerNumber'];

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isCurrentPlayer ? Colors.blue.shade50 : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isCurrentPlayer ? Colors.blue : Colors.transparent),
          ),
          child: Text(
            '${player['username']} (${player['playerNumber'] == 1 ? 'Black ⚫' : 'White ⚪'})${isCurrentPlayer ? ' 🎯' : ''}',
            style: TextStyle(fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal, color: isCurrentPlayer ? Colors.blue : Colors.black),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGameControls(GameProvider gameProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (gameProvider.canStartGame) ElevatedButton(onPressed: _startGame, child: const Text('Start Game')),

        if (gameProvider.gameOver && gameProvider.role == 'player') ElevatedButton(onPressed: _resetGame, child: const Text('Play Again')),
      ],
    );
  }

  Widget _buildSidePanel(GameProvider gameProvider) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Chat Header
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Chat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),

          // Chat Messages
          Expanded(child: _buildChatMessages(gameProvider)),

          // Message Input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildChatMessages(GameProvider gameProvider) {
    final messages = gameProvider.chatMessages;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        reverse: true,
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[messages.length - 1 - index];
          final isCurrentUser = message['user_id'] == gameProvider.currentUser?.id;

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isCurrentUser)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message['username'] ?? 'Unknown',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                          Text(message['message'] ?? ''),
                        ],
                      ),
                    ),
                  ),
                if (isCurrentUser)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'You',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                          Text(message['message'] ?? ''),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(hintText: 'Type a message...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12)),
              onSubmitted: (value) => _sendMessage(),
            ),
          ),
          IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage, color: Colors.blue),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isMounted = false;
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        // Обработка случая когда комната не найдена
        if (gameProvider.roomId == null || gameProvider.currentRoom == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Room Not Found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('The room may have been deleted or you were disconnected.'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Return to Lobby'),
                  ),
                ],
              ),
            ),
          );
        }
        // Показываем индикатор загрузки пока подписки не инициализированы
        if (!_isSubscribed || gameProvider.roomId == null) {
          return const Scaffold(
            body: Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Connecting to room...')]),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(gameProvider.currentRoom?['name'] ?? 'Room'),
            actions: [
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                onPressed: () {
                  gameProvider.leaveRoom();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          body: Row(
            children: [
              // Game Board
              Expanded(flex: 2, child: _buildGameBoard(gameProvider)),

              // Chat and Info
              Expanded(flex: 1, child: _buildSidePanel(gameProvider)),
            ],
          ),
        );
      },
    );
  }
}
