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

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
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
          body: gameProvider.currentRoom == null
              ? const Center(child: CircularProgressIndicator())
              : Row(
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
              ),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 15),
                itemCount: 225,
                itemBuilder: (context, index) {
                  final row = index ~/ 15;
                  final col = index % 15;
                  final cellValue = gameProvider.board[row][col];

                  return GestureDetector(
                    onTap: () {
                      if (gameProvider.gameStarted && !gameProvider.gameOver && gameProvider.role == 'player' && gameProvider.currentPlayer == gameProvider.playerNumber) {
                        gameProvider.makeMove(row, col);
                      }
                    },
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

  Widget _buildStone(int value) {
    if (value == 0) return const SizedBox.shrink();

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: value == 1 ? Colors.black : Colors.white,
        shape: BoxShape.circle,
        border: value == -1 ? Border.all(color: Colors.black) : null,
      ),
    );
  }

  Widget _buildGameInfo(GameProvider gameProvider) {
    String status = '';
    if (!gameProvider.gameStarted) {
      status = 'Waiting for players...';
    } else if (gameProvider.gameOver) {
      status = gameProvider.winner == 0 ? 'Game Over: Draw!' : 'Game Over: Player ${gameProvider.winner} wins!';
    } else {
      status = 'Current player: ${gameProvider.currentPlayer == 1 ? 'Black' : 'White'}';
      if (gameProvider.role == 'player') {
        status += ' (You are Player ${gameProvider.playerNumber})';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(status, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Players: ${gameProvider.currentRoom?['players'].map((p) => '${p['username']} (${p['playerNumber'] == 1 ? 'Black' : 'White'})').join(', ')}'),
            if (gameProvider.currentRoom?['spectators'].isNotEmpty == true) Text('Spectators: ${gameProvider.currentRoom?['spectators'].map((s) => s['username']).join(', ')}'),
          ],
        ),
      ),
    );
  }

  Widget _buildGameControls(GameProvider gameProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (gameProvider.currentRoom?['players'].length == 2 && !gameProvider.gameStarted && gameProvider.role == 'player')
          ElevatedButton(onPressed: gameProvider.startGame, child: const Text('Start Game')),
        if (gameProvider.gameOver && gameProvider.role == 'player') ElevatedButton(onPressed: gameProvider.resetGame, child: const Text('Play Again')),
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
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: gameProvider.chatMessages.length,
              itemBuilder: (context, index) {
                final message = gameProvider.chatMessages[gameProvider.chatMessages.length - 1 - index];
                return ListTile(
                  title: Text(message['username'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(message['message']),
                  dense: true,
                );
              },
            ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(hintText: 'Type a message...', border: InputBorder.none),
                    onSubmitted: (value) => _sendMessage(gameProvider),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: () => _sendMessage(gameProvider)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(GameProvider gameProvider) {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      gameProvider.sendMessage(message);
      _messageController.clear();
    }
  }
}
