// lib/screens/listen_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../services/detect_service.dart';
import '../state/app_state.dart';
import '../models/song.dart';
import '../widgets/audio_visualizer.dart';

class ListenScreen extends StatefulWidget {
  const ListenScreen({super.key});

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  final DetectService _detectService = DetectService();
  bool _scanning = false;
  StreamSubscription<Amplitude>? _ampSub;
  List<double> _amplitudes = List.filled(30, 0.0);

  @override
  void dispose() {
    _ampSub?.cancel();
    super.dispose();
  }

  Future<void> _onDetectPressed() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _amplitudes = List.filled(30, 0.0, growable: true);
    });

    // Start listening to amplitude
    _ampSub = _detectService.amplitudeStream.listen((amp) {
      if (!mounted) return;
      // Normalizing db: usually -160 to 0. simple map: (amp.current + 160) / 160
      // But typical speech is -60 to 0. 
      // simple normalized: (current + 60) / 60, clamped 0..1
      double val = (amp.current + 60) / 60;
      if (val < 0) val = 0;
      if (val > 1) val = 1;

      setState(() {
        _amplitudes.removeAt(0);
        _amplitudes.add(val);
      });
    });

    try {
      final Song detected = await _detectService.detectSong();

      if (!mounted) return;

      // Persist via provider
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.addDetectedSong(detected);
      appState.setSelectedSong(detected);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Detected: ${detected.title} — ${detected.artist}')),
      );

      // open song page
      Navigator.of(context).pushNamed('/song', arguments: detected);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Detection failed: $e')),
        );
      }
    } finally {
      _ampSub?.cancel();
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Tap to Listen', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            
            if (_scanning)
              Column(children: [
                AudioVisualizer(amplitudes: _amplitudes),
                const SizedBox(height: 20),
                const Text('Listening...', style: TextStyle(color: Colors.grey)),
              ])
            else
              GestureDetector( // Big fancy button
                onTap: _onDetectPressed,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 5)
                    ],
                  ),
                  child: const Icon(Icons.mic, size: 60, color: Colors.white),
                ),
              ),

            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/history'),
              icon: const Icon(Icons.history),
              label: const Text('Open History'),
            ),
          ]),
        ),
      ),
    );
  }
}
