import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'config/app_theme.dart';
import 'services/app_state.dart';
import 'utils/trackit_responsive.dart';

class TrackitApp extends StatelessWidget {
  const TrackitApp({super.key, required this.appState, required this.router});

  final AppState appState;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: Consumer<AppState>(
        builder: (context, app, _) {
          return MaterialApp.router(
            title: 'TrackIT',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: app.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            routerConfig: router,
            builder: (context, child) {
              return MediaQuery(
                data: clampTrackitTextScale(MediaQuery.of(context)),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
