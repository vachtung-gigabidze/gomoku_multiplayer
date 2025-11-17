import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:gomoku_multiplayer/app.dart';

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   runZonedGuarded(() {
//     runApp(const GomokuApp());
//   }, (error, stack) {});
// }
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gomoku_multiplayer/services/supabase_service.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gomoku_multiplayer/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await SupabaseService.initialize(); //initialize(url: dotenv.env['SUPABASE_URL'] ?? "SUPABASE_URL", anonKey: dotenv.env['SUPABASE_ANONKEY'] ?? "SUPABASE_ANONKEY");

  // runZonedGuarded(() {
  runApp(const GomokuApp());
  //  }, (error, stack) {});
}
