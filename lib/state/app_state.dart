// lib/state/app_state.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/song.dart';

const String _boxName = 'detected_songs';

class AppState extends ChangeNotifier {
  /// In-memory list (newest first)
  List<Song> detectedSongs = [];

  /// Selected song
  Song? selectedSong;

  /// The Hive box instance
  Box<Song>? _box;

  /// Load from Hive (call once on startup)
  Future<void> loadFromBox() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SongAdapter());
    }
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox<Song>(_boxName);
    } else {
      _box = Hive.box<Song>(_boxName);
    }

    // Load into memory in reverse so newest at index 0
    detectedSongs = _box!.values.toList().reversed.toList();
    if (detectedSongs.isNotEmpty) {
      selectedSong ??= detectedSongs.first;
    }
    notifyListeners();
  }

  /// Add detected song (persisted)
  Future<void> addDetectedSong(Song song) async {
    _box ??= Hive.box<Song>(_boxName);
    await _box!.add(song);
    detectedSongs.insert(0, song);
    selectedSong = song;
    notifyListeners();
  }

  /// Update an existing song (persist change like chords)
  Future<void> updateSong(Song song) async {
    _box ??= Hive.box<Song>(_boxName);

    // Find key by matching title+artist+detectedAt
    int? foundKey;
    for (final entry in _box!.toMap().entries) {
      final val = entry.value;
      if (val.title == song.title &&
          val.artist == song.artist &&
          val.detectedAt == song.detectedAt) {
        foundKey = entry.key as int;
        break;
      }
    }

    if (foundKey != null) {
      await _box!.put(foundKey, song);
    } else {
      // If not found, add as new
      await _box!.add(song);
    }

    // Update in-memory list
    final idx = detectedSongs.indexWhere((s) =>
    s.title == song.title &&
        s.artist == song.artist &&
        s.detectedAt == song.detectedAt);
    if (idx != -1) {
      detectedSongs[idx] = song;
    } else {
      detectedSongs.insert(0, song);
    }

    selectedSong = song;
    notifyListeners();
  }

  /// Set selected song (does not persist)
  void setSelectedSong(Song? song) {
    selectedSong = song;
    notifyListeners();
  }

  /// Delete a song by in-memory index
  Future<void> deleteAt(int index) async {
    if (index < 0 || index >= detectedSongs.length) return;
    _box ??= Hive.box<Song>(_boxName);

    final target = detectedSongs[index];

    int? foundKey;
    for (final entry in _box!.toMap().entries) {
      final val = entry.value;
      if (val.title == target.title &&
          val.artist == target.artist &&
          val.detectedAt == target.detectedAt) {
        foundKey = entry.key as int;
        break;
      }
    }
    if (foundKey != null) {
      await _box!.delete(foundKey);
    }

    detectedSongs.removeAt(index);

    if (selectedSong == target) {
      selectedSong = detectedSongs.isNotEmpty ? detectedSongs.first : null;
    }

    notifyListeners();
  }

  /// Clear all
  Future<void> clearAll() async {
    _box ??= Hive.box<Song>(_boxName);
    await _box!.clear();
    detectedSongs.clear();
    selectedSong = null;
    notifyListeners();
  }
}
