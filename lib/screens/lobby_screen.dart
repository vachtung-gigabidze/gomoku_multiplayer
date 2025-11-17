import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gomoku_multiplayer/providers/game_provider.dart';
import 'package:gomoku_multiplayer/screens/auth_screen.dart';
import 'package:gomoku_multiplayer/screens/room_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _roomNameController = TextEditingController();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() async {
    // Ждем завершения build перед инициализацией
    await Future.delayed(Duration.zero);

    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    gameProvider.subscribeToRooms();
    gameProvider.loadRooms();

    setState(() {
      _isInitialized = true;
    });
  }

  void _createRoom(BuildContext context) async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    if (_roomNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter room name')));
      return;
    }

    try {
      await gameProvider.createRoom(_roomNameController.text);
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const RoomScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating room: $e')));
      }
    }
  }

  void _joinRoom(BuildContext context, String roomId) async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    try {
      await gameProvider.joinRoom(roomId);
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const RoomScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error joining room: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        // Показываем индикатор загрузки во время инициализации
        if (!_isInitialized || gameProvider.isLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!gameProvider.isAuthenticated) {
          return const AuthScreen();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Gomoku Lobby'),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: () => gameProvider.loadRooms()),
              IconButton(icon: const Icon(Icons.logout), onPressed: () => gameProvider.signOut()),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text('Welcome, ${gameProvider.username ?? 'Player'}!', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Online: ${gameProvider.rooms.length} rooms', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Create Room Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Create Room', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _roomNameController,
                          decoration: const InputDecoration(labelText: 'Room Name', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(onPressed: () => _createRoom(context), child: const Text('Create Room')),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Available Rooms Section
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Available Rooms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          gameProvider.rooms.isEmpty
                              ? const Center(child: Text('No rooms available', style: TextStyle(fontSize: 16)))
                              : Expanded(
                                  child: ListView.builder(
                                    itemCount: gameProvider.rooms.length,
                                    itemBuilder: (context, index) {
                                      final room = gameProvider.rooms[index];
                                      final players = List<Map<String, dynamic>>.from(room['players']);
                                      final gameState = Map<String, dynamic>.from(room['game_state']);

                                      return Card(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        child: ListTile(
                                          title: Text(room['name']),
                                          subtitle: Text(
                                            'Players: ${players.length}/2 • '
                                            'Created by: ${room['created_by']}',
                                          ),
                                          trailing: gameState['gameStarted']
                                              ? const Chip(label: Text('In Game'), backgroundColor: Colors.orange)
                                              : players.length >= 2
                                              ? const Chip(label: Text('Full'), backgroundColor: Colors.red)
                                              : const Chip(label: Text('Join'), backgroundColor: Colors.green),
                                          onTap: players.length >= 2 || gameState['gameStarted'] ? null : () => _joinRoom(context, room['id']),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
