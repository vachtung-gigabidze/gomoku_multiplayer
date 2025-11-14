import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gomoku_multiplayer/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runZonedGuarded(() {
    runApp(const GomokuApp());
  }, (error, stack) {});
}
