import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gomoku_multiplayer/providers/game_provider.dart';
import 'package:gomoku_multiplayer/screens/lobby_screen.dart';
import 'package:gomoku_multiplayer/screens/room_screen.dart';

class GomokuApp extends StatelessWidget {
  const GomokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => GameProvider())],
      child: MaterialApp(
        title: 'Gomoku Multiplayer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        home: const LobbyScreen(),
        routes: {'/room': (context) => const RoomScreen()},
      ),
    );
  }
}
