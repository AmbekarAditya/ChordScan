// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/song_tile.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<AppState>(builder: (context, appState, _) {
        final songs = appState.detectedSongs;
        return Scaffold(
          appBar: AppBar(
            title: const Text("History"),
            actions: [
              if (songs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_all),
                  onPressed: () async {
                    await appState.clearAll();
                  },
                ),
            ],
          ),
          body: songs.isEmpty
              ? const Center(
            child: Text("No detected songs yet.\nGo to Listen tab to detect.", textAlign: TextAlign.center),
          )
              : ListView.separated(
            itemCount: songs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final s = songs[index];
              return SongTile(
                song: s,
                onTap: () => Navigator.of(context).pushNamed('/song', arguments: s),
                onOpen: () => Navigator.of(context).pushNamed('/song', arguments: s),
                onDelete: () async {
                  await appState.deleteAt(index);
                },
              );
            },
          ),
        );
      }),
    );
  }
}
