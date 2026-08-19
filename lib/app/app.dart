import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme.dart';

class SawataApp extends StatelessWidget {
  const SawataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sawata',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorKey: AppRoutes.navigatorKey,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
