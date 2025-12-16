// lib/screens/song_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/song.dart';
import '../services/chord_service.dart';
import '../state/app_state.dart';
import '../widgets/chord_box.dart';

class SongScreen extends StatefulWidget {
  const SongScreen({super.key});

  @override
  State<SongScreen> createState() => _SongScreenState();
}

class _SongScreenState extends State<SongScreen> {
  final ChordService _chordService = ChordService();
  bool _loading = false;
  Song? _song;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    final appState = Provider.of<AppState>(context, listen: false);

    if (args != null && args is Song) {
      _song = args;
      Future.microtask(() => appState.setSelectedSong(_song));
    } else {
      _song = appState.selectedSong;
    }
  }

  Future<void> _fetchChords() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (_song == null) return;
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final chords = await _chordService.fetchChords(_song!);
      _song!.chords = chords;
      await appState.updateSong(_song!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fetch failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _launchSearch() async {
    if (_song == null) return;
    final query = Uri.encodeComponent('${_song!.title} ${_song!.artist} chords');
    final url = Uri.parse('https://www.google.com/search?q=$query');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch search')));
      }
    }
  }

  void _showEditDialog() {
    if (_song == null) return;
    final controller = TextEditingController(text: _song!.chords);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Chords'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _song!.chords = controller.text;
              await Provider.of<AppState>(context, listen: false).updateSong(_song!);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<AppState>(builder: (context, appState, _) {
        final s = _song ?? appState.selectedSong;
        return Scaffold(
          appBar: AppBar(
            title: Text(s?.title ?? 'Song'),
            actions: [
              if (s != null)
                IconButton(icon: const Icon(Icons.edit), onPressed: _showEditDialog),
              if (s != null)
                 IconButton(icon: const Icon(Icons.search), onPressed: _launchSearch),
            ],
          ),
          body: s == null
              ? const Center(child: Text('No song selected'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(s.artist, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                    const SizedBox(height: 16),
                    if (s.chords == null || s.chords!.isEmpty)
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _fetchChords,
                          icon: _loading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.download),
                          label: Text(_loading ? 'Fetching...' : 'Get Chords'),
                        ),
                      )
                    else
                      Expanded(
                        child: ChordBox(text: s.chords!),
                      ),
                  ]),
                ),
        );
      }),
    );
  }
}
