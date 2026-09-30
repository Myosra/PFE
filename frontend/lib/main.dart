import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() => runApp(const FeedingTrackerApp());

const water = Color(0xFF0C2A33);
const pellet = Color(0xFFF2B441);

class FeedingTrackerApp extends StatelessWidget {
  const FeedingTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: pellet,
      brightness: Brightness.dark,
    ).copyWith(surface: water, primary: pellet, onPrimary: const Color(0xFF231700));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fish feeding tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: water,
      ),
      home: const HomeScreen(),
    );
  }
}
