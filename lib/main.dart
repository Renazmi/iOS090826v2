import 'package:flutter/material.dart';

import 'app.dart';
import 'routes/app_router.dart';
import 'services/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = await AppState.create();
  final router = createAppRouter(appState);
  runApp(TrackitApp(appState: appState, router: router));
}
