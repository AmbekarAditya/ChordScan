// lib/widgets/song_tile.dart
import 'package:flutter/material.dart';
import '../models/song.dart';

/// A reusable ListTile for songs used in History.
/// - shows avatar, title, artist and time
/// - primaryTap / trailing callbacks are exposed
class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onOpen; // trailing open / details
  final VoidCallback? onDelete;

  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.onOpen,
    this.onDelete,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Colors.amber[200],
        child: Text(
          (song.title.isNotEmpty ? song.title[0] : '?'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_timeAgo(song.detectedAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          if (onOpen != null)
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: onOpen,
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
