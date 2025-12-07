// lib/widgets/chord_box.dart
import 'package:flutter/material.dart';

/// A simple styled container to display chord text. Scrollable.
class ChordBox extends StatelessWidget {
  final String text;
  final EdgeInsets padding;

  const ChordBox({
    super.key,
    required this.text,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: const TextStyle(fontFamily: 'monospace', height: 1.3),
        ),
      ),
    );
  }
}
