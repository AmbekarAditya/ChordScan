// lib/main.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'models/song.dart';
import 'state/app_state.dart';
import 'screens/listen_screen.dart';
import 'screens/history_screen.dart';
import 'screens/song_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // DEBUG BUILD MARKER (for GitHub Pages check)
  print('BUILD_MARKER:ChordScanBuild');

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(SongAdapter());

  // Open box for detected songs
  await Hive.openBox<Song>('detected_songs');

  // Create AppState and load initial data
  final appState = AppState();
  await appState.loadFromBox();

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const ChordScanApp(),
    ),
  );
}

class ChordScanApp extends StatelessWidget {
  const ChordScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChordScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.amber),
      home: const BottomNavShell(),
      routes: {
        '/song': (context) => const SongScreen(),
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}

class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _index = 0;

  final List<Widget> _pages = const [
    ListenScreen(),
    HistoryScreen(),
    SongScreen(),
  ];

  void _onTap(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Listen'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'Song'),
        ],
      ),
    );
  }
}
