// lib/utils/dummy_songs.dart

import '../models/song.dart';

/// A mock pool of songs for detection simulation.
/// When user taps "Detect", we randomly choose one from here.

final List<Song> mockSongPool = [
  Song(title: 'Gulabi Aankhein', artist: 'Mohammed Rafi'),
  Song(title: 'Shape of You', artist: 'Ed Sheeran'),
  Song(title: 'Kesariya', artist: 'Arijit Singh'),
  Song(title: 'Blinding Lights', artist: 'The Weeknd'),
  Song(title: 'Tera Yaar Hoon Main', artist: 'Arijit Singh'),
  Song(title: 'Mocked Melody', artist: 'Demo Artist'),
  Song(title: 'Perfect', artist: 'Ed Sheeran'),
  Song(title: 'Raabta', artist: 'Arijit Singh'),
  Song(title: 'Believer', artist: 'Imagine Dragons'),
  Song(title: 'Night Changes', artist: 'One Direction'),
];
