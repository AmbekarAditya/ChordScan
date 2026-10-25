// lib/services/chord_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../utils/secrets.dart';

class ChordService {
  
  // Model Options
  static const String modelQwen = "qwen/qwen-2.5-72b-instruct";
  static const String modelGemini = "google/gemini-2.0-flash-exp:free";
  static const String modelLlama = "meta-llama/llama-3.3-70b-instruct";
  static const String modelAmazon = "amazon/nova-2-lite-v1:free";
  static const String modelQwenCoder = "qwen/qwen-2.5-coder-32b-instruct:free";

  // Configuration
  final String _currentModel = modelQwenCoder; // Default to Qwen Coder

  /// Deep Research Fetch: Search Multiple Sources -> Compile -> LLM Harmonize
  Future<String> fetchChords(Song song) async {
    List<String> researchResults = [];
    
    try {
      // 1. Perform Deep Research (Parallel Search)
      print('Starting Deep Research for: ${song.title}');
      researchResults = await _performDeepResearch(song);

      if (Secrets.openRouterApiKey == 'PUT_YOUR_OPENROUTER_KEY_HERE' ||
          Secrets.openRouterApiKey.isEmpty) {
        if (researchResults.isNotEmpty) {
          return _formatBestScrapedResult(researchResults);
        }
        return _generateFallback(song, 'Please configure your OpenRouter API Key in lib/utils/secrets.dart');
      }
      
      // 2. Harmonize with LLM
      print('Harmonizing ${researchResults.length} sources with LLM...');
      final content = await _harmonizeWithLLM(song, researchResults);
      
      if (content != null && content.trim().isNotEmpty) {
        return content; // Contains source info footer from LLM
      }
    } catch (e) {
      print('ChordService Error: $e');
      
      // FALLBACK: If LLM fails (e.g. 401), but we found research, return the clean scraped chord sheet!
      if (researchResults.isNotEmpty) {
        print('LLM unavailable ($e), returning clean scraped chord sheet.');
        return _formatBestScrapedResult(researchResults);
      }
      return _generateFallback(song, 'Error: $e. (Try adding manual chords)'); 
    }

    if (researchResults.isNotEmpty) {
      return _formatBestScrapedResult(researchResults);
    }
    return _generateFallback(song, 'Could not generate chords (No sources found).');
  }

  String _formatBestScrapedResult(List<String> researchResults) {
    // Prefer Ultimate-Guitar if present, otherwise take the first clean result
    final ugResult = researchResults.where((r) => r.contains('Ultimate-Guitar') || r.contains('ultimate-guitar.com')).firstOrNull;
    if (ugResult != null) {
      return ugResult;
    }
    return researchResults.first;
  }

  // --- Deep Research ---

  /// Strip parenthetical/bracketed metadata like (From "Kabir Singh"), [feat. ...], etc.
  String _cleanQueryPart(String input) {
    return input
        .replaceAll(RegExp(r'\s*[\(\[][^\)\]]*[\)\]]'), '')
        .replaceAll(RegExp(r'\s*-\s*(Remaster|From|Live|Radio|Single| Soundtrack).*', caseSensitive: false), '')
        .replaceAll('"', '')
        .trim();
  }

  Future<List<String>> _performDeepResearch(Song song) async {
    final results = <String>[];

    final cleanTitle = _cleanQueryPart(song.title);
    final cleanArtist = _cleanQueryPart(song.artist);
    final baseQuery = '$cleanTitle $cleanArtist'.trim();

    // Define search queries for different high-quality targets
    final queries = [
      '$baseQuery chords site:ultimate-guitar.com',
      if (cleanTitle.isNotEmpty) '$cleanTitle chords site:ultimate-guitar.com',
      '$baseQuery chords site:azchords.com',
      '$baseQuery chords site:guitartabs.cc',
    ];

    // Run searches in parallel
    final tasks = queries.map((q) => _searchAndScrape(q)).toList();

    final searchOutputs = await Future.wait(tasks);

    for (var output in searchOutputs) {
      if (output != null && output.length > 50) {
        results.add(output);
      }
    }

    // Fallback logic...
    if (results.isEmpty) {
       print('Site-specific searches failed. Trying generic...');
       final generic = await _searchAndScrape('$baseQuery chords');
       if (generic != null) results.add(generic);
    }

    return results;
  }

  Future<String?> _searchAndScrape(String query) async {
    try {
      // 1. Search DDG
      print('DDG Search: $query');
      final searchUrl = 'https://html.duckduckgo.com/html/?q=${Uri.encodeComponent(query)}';
      final searchResp = await _fetchWithProxy(searchUrl);
      
      if (searchResp.statusCode != 200) {
         print('DDG Search Failed (${searchResp.statusCode}) for: $query');
         return null;
      }

      String? targetLink;

      // Extract first non-ad DuckDuckGo redirect URL (works for both HTML and Jina Markdown)
      final uddgMatches = RegExp(r'uddg=([^&\s\)"\x27]+)').allMatches(searchResp.body);
      for (final m in uddgMatches) {
        final raw = m.group(1);
        if (raw != null) {
          final decoded = Uri.decodeComponent(raw);
          if (decoded.startsWith('http') && !decoded.contains('duckduckgo.com')) {
            targetLink = decoded;
            print('DDG: Decoded redirect -> $targetLink');
            break;
          }
        }
      }

      if (targetLink == null) {
        final searchDoc = html.parse(searchResp.body);
        final link = searchDoc.querySelector('.result__a')?.attributes['href'] ?? 
                     searchDoc.querySelector('.result__snippet')?.attributes['href'];
        if (link != null && !link.contains('duckduckgo.com')) {
          targetLink = link;
        }
      }
      
      if (targetLink == null) {
        print('DDG: No results found for: $query');
        return null;
      }

      print('DDG: Scraping $targetLink');
      // For Ultimate-Guitar on non-Web, also use Jina proxy so React store is rendered into a <pre> code block
      final pageResp = (!kIsWeb && targetLink.contains('ultimate-guitar.com'))
          ? await _fetchViaJinaOrDirect(targetLink)
          : await _fetchWithProxy(targetLink);
      if (pageResp.statusCode != 200) {
        print('Page Fetch Failed (${pageResp.statusCode}): $targetLink');
        return null;
      }

      return _extractCleanTabContent(pageResp.body, targetLink);
    } catch (e) {
      print('Scrape error for "$query": $e');
      return null;
    }
  }

  String? _extractCleanTabContent(String body, String targetLink) {
    final host = Uri.parse(targetLink).host;

    // Guard against artist directory / index tables
    if (body.contains('| Band name | # of tabs |') || body.contains('**Artists 0-9**')) {
      return null;
    }

    // 1. Check for fenced Markdown code blocks (e.g. Jina Reader on Ultimate-Guitar)
    final codeBlocks = RegExp(r'```[^\n]*\n([\s\S]*?)```').allMatches(body);
    for (final match in codeBlocks) {
      final content = match.group(1)?.trim() ?? '';
      if (content.length > 50) {
        return '$content\n\n[Source: $host]';
      }
    }

    // 2. Check for Jina Reader Markdown Content (e.g. AZChords / GuitarTabs.cc)
    const mdMarker = 'Markdown Content:';
    final mdIdx = body.indexOf(mdMarker);
    if (mdIdx != -1) {
      var md = body.substring(mdIdx + mdMarker.length).trim();
      // Remove markdown images ![...](...)
      md = md.replaceAll(RegExp(r'!\[[^\]]*\]\([^\)]*\)'), '');
      // Remove empty markdown links [](...)
      md = md.replaceAll(RegExp(r'\[\s*\]\([^\)]*\)'), '');
      // Unwrap markdown links [Chord](url) -> Chord
      md = md.replaceAllMapped(RegExp(r'\[([^\]]+)\]\(https?:\/\/[^\)]+\)'), (m) => m.group(1) ?? '');

      // Trim header navigation clutter before chord content if present
      final startMarkers = ['Chords used:', 'Capo ', '[Intro]', '[Verse', 'Verse 1'];
      for (final marker in startMarkers) {
        final idx = md.indexOf(marker);
        if (idx != -1 && idx < 1500) {
          md = md.substring(idx);
          break;
        }
      }

      md = md.trim();
      if (md.length > 50) {
        final clipped = md.length > 6000 ? md.substring(0, 6000) : md;
        return '$clipped\n\n[Source: $host]';
      }
    }

    // 3. Raw HTML Fallback
    final pageDoc = html.parse(body);
    final pre = pageDoc.querySelector('js-tab-content') ?? pageDoc.querySelector('pre');
    if (pre != null && pre.text.trim().length > 50) {
      return '${pre.text.trim()}\n\n[Source: $host]';
    }

    pageDoc.querySelectorAll('script, style, meta, link, noscript').forEach((e) => e.remove());
    var bodyText = pageDoc.body?.text.trim() ?? '';
    bodyText = bodyText.split('\n').where((line) {
      final l = line.trim();
      if (l.isEmpty) return false;
      if (l.startsWith('{') || l.startsWith('"') || l.startsWith('.') || l.startsWith('@')) return false;
      if (l.contains('function()')) return false;
      if (l.length < 3) return false;
      return true;
    }).join('\n');

    if (bodyText.length <= 50) return null;
    final clipped = bodyText.length > 5000 ? bodyText.substring(0, 5000) : bodyText;
    return '$clipped\n\n[Source: $host]';
  }

  Future<http.Response> _fetchViaJinaOrDirect(String url) async {
    try {
      final response = await http.get(Uri.parse('https://r.jina.ai/$url')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return response;
    } catch (_) {}
    return http.get(Uri.parse(url), headers: {'User-Agent': 'ChordScan/1.0'});
  }

  /// Helper to fetch URL with CORS proxy on Web
  Future<http.Response> _fetchWithProxy(String url) async {
    if (!kIsWeb) {
      return http.get(Uri.parse(url), headers: {'User-Agent': 'ChordScan/1.0'});
    }

    // 1. Primary: Jina Reader (CORS simple GET request, renders JS tabs cleanly)
    try {
      final target = 'https://r.jina.ai/$url';
      final response = await http.get(Uri.parse(target)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return response;
      print('Proxy 1 (Jina) failed: ${response.statusCode}');
    } catch (e) {
      print('Proxy 1 (Jina) error: $e');
    }

    // 2. Secondary: cors.lol
    try {
      print('Switching to Proxy 2 (cors.lol)...');
      final target = 'https://api.cors.lol/?url=${Uri.encodeComponent(url)}';
      final response = await http.get(Uri.parse(target)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return response;
      print('Proxy 2 (cors.lol) failed: ${response.statusCode}');
    } catch (e) {
      print('Proxy 2 (cors.lol) error: $e');
    }

    // 3. Tertiary: AllOrigins
    try {
      print('Switching to Proxy 3 (AllOrigins)...');
      final target = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
      return await http.get(Uri.parse(target)).timeout(const Duration(seconds: 10));
    } catch (e) {
      print('All Proxies Failed for $url: $e');
      rethrow;
    }
  }

  // --- LLM Harmonization ---

  Future<String?> _harmonizeWithLLM(Song song, List<String> sources) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    
    // Construct Context
    final sb = StringBuffer();
    bool isGenerationMode = sources.isEmpty;

    if (!isGenerationMode) {
      sb.writeln("I have found the following potential versions from the web:");
      for (int i = 0; i < sources.length; i++) {
        sb.writeln("--- VERSION ${i + 1} ---");
        final s = sources[i];
        sb.writeln(s.length > 3000 ? s.substring(0, 3000) : s);
        sb.writeln("---------------------");
      }
    } else {
      sb.writeln("Research failed to find specific versions. PLEASE GENERATE FROM YOUR TRAINING DATA.");
      sb.writeln("IMPORTANT: You must output the FULL LYRICS with Chords. Do not output chords only.");
    }

    final systemPrompt = """
You are a Music Director and Expert Transcriber.
Your goal is to create the **Definitive Master Chord Sheet** for "${song.title}" by "${song.artist}".

TASK:
${isGenerationMode ? "1. **GENERATE**: Write the full song (Lyrics + Chords) from memory/training data." : "1. **Analyze**: Look at all provided versions."}
${isGenerationMode ? "2. **Structure**: Include all Verses and Choruses. VERIFY lyrics are the OFFICIAL CLEAN RADIO EDIT. Do NOT use parody or wrong lyrics." : "2. **Harmonize**: Combine the best parts. Overlay chords onto official lyrics if available."}
3.  **Format**: strict "Chords over Lyrics" format. standard tuning.
4.  **Output**: Return ONLY the chord sheet. No intro/outro/markdown.

CRITICAL: The output MUST include the lyrics. Do not just list the chords. USE STANDARD ENGLISH LYRICS.

Add a footer line: "[Compiled from ${sources.length} sources by $_currentModel]"
""";

    try {
      print('OpenRouter: Sending request with key prefix: ${Secrets.openRouterApiKey.substring(0, 10)}...');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${Secrets.openRouterApiKey}',
          'Content-Type': 'application/json',
          // 'Or-Site-Url': 'https://ambekaraditya.github.io/ChordScan/', // Optional: for OpenRouter rankings
          // 'Or-App-Name': 'ChordScan',
        },
        body: jsonEncode({
          "model": _currentModel,
          "messages": [
            {
              "role": "system",
              "content": systemPrompt
            },
            {
              "role": "user",
              "content": sb.toString()
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices']?[0]?['message']?['content'] as String?;
      } else {
        print('OpenRouter Error: ${response.statusCode} ${response.body}');
        throw Exception('OpenRouter ${response.statusCode}'); // Throw to trigger custom error msg
      }
    } catch(e) {
       print("LLM Error: $e");
       rethrow;
    }
  }

  String _generateFallback(Song song, String reason) {
    final query = Uri.encodeComponent('${song.title} ${song.artist} chords');
    return '''
Could not generate chords.
Error: $reason

Try searching online:
https://www.ultimate-guitar.com/search.php?search_type=title&value=$query

Or add them manually by tapping "Edit".
''';
  }
}
