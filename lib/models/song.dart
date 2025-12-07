// lib/models/song.dart
import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class Song {
  @HiveField(0)
  final String title;

  @HiveField(1)
  final String artist;

  @HiveField(2)
  String? chords;

  @HiveField(3)
  DateTime detectedAt;

  Song({
    required this.title,
    required this.artist,
    this.chords,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();
}

/// Manual Hive TypeAdapter (no codegen needed)
class SongAdapter extends TypeAdapter<Song> {
  @override
  final int typeId = 0;

  @override
  Song read(BinaryReader reader) {
    final totalFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < totalFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Song(
      title: fields[0] as String,
      artist: fields[1] as String,
      chords: fields[2] as String?,
      detectedAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Song obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.artist)
      ..writeByte(2)
      ..write(obj.chords)
      ..writeByte(3)
      ..write(obj.detectedAt);
  }
}
