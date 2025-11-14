import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gomoku_multiplayer/providers/game_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController(text: 'http://localhost:3000');

  List<dynamic> _rooms = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _loading = true);
    try {
      final response = await http.get(Uri.parse('${_serverUrlController.text}/api/rooms'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _rooms = data['rooms']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load rooms: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _connectToServer(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    if (_usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your username')));
      return;
    }

    gameProvider.setUsername(_usernameController.text);
    gameProvider.setServerUrl(_serverUrlController.text);
    gameProvider.initSocket();

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecting to server...')));
  }

  void _createRoom(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    if (_roomNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter room name')));
      return;
    }

    gameProvider.createRoom(_roomNameController.text);
    Navigator.pushNamed(context, '/room');
  }

  void _joinRoom(BuildContext context, String roomId) {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    gameProvider.joinRoom(roomId);
    Navigator.pushNamed(context, '/room');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gomoku Lobby'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRooms)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _serverUrlController,
                      decoration: const InputDecoration(labelText: 'Server URL', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(onPressed: () => _connectToServer(context), child: const Text('Connect')),
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
                      _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _rooms.isEmpty
                          ? const Center(child: Text('No rooms available'))
                          : Expanded(
                              child: ListView.builder(
                                itemCount: _rooms.length,
                                itemBuilder: (context, index) {
                                  final room = _rooms[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: ListTile(
                                      title: Text(room['name']),
                                      subtitle: Text(
                                        'Players: ${room['playerCount']}/2 • '
                                        'Created by: ${room['createdBy']}',
                                      ),
                                      trailing: room['gameStarted']
                                          ? const Chip(label: Text('In Game'), backgroundColor: Colors.orange)
                                          : room['playerCount'] >= 2
                                          ? const Chip(label: Text('Full'), backgroundColor: Colors.red)
                                          : const Chip(label: Text('Join'), backgroundColor: Colors.green),
                                      onTap: room['playerCount'] >= 2 || room['gameStarted'] ? null : () => _joinRoom(context, room['id']),
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
  }
}
