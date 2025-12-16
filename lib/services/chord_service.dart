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
      if (Secrets.openRouterApiKey == 'PUT_YOUR_OPENROUTER_KEY_HERE') {
        return _generateFallback(song, 'Please configure your OpenRouter API Key in lib/utils/secrets.dart');
      }

      // 1. Perform Deep Research (Parallel Search)
      print('Starting Deep Research for: ${song.title}');
      researchResults = await _performDeepResearch(song);
      
      // 2. Harmonize with LLM
      print('Harmonizing ${researchResults.length} sources with LLM...');
      final content = await _harmonizeWithLLM(song, researchResults);
      
      if (content != null) {
        return content; // Contains source info footer from LLM
      }
    } catch (e) {
      print('ChordService Error: $e');
      
      // FALLBACK: If LLM fails (e.g. 401), but we found raw research, return that!
      if (researchResults.isNotEmpty) {
         print('LLM failed, but returning raw research.');
         // We simply join the raw text. It won't be pretty (HTML stripped), but it's readable content.
         final rawContent = researchResults.map((r) => "--- SOURCE OPTION ---\n$r").join("\n\n");
         return "AUTOMATED HARMONIZATION FAILED (API Error). PROVISIONAL RAW RESULTS:\n\n$rawContent\n\n(Error Detail: $e)";
      }
      return _generateFallback(song, 'Error: $e. (Try adding manual chords)'); 
    }

    return _generateFallback(song, 'Could not generate chords (Unknown Error).');
  }

  // --- Deep Research ---

  Future<List<String>> _performDeepResearch(Song song) async {
    final results = <String>[];

    // Define search queries for different high-quality targets
    final queries = [
      '${song.title} ${song.artist} chords site:ultimate-guitar.com',
      '${song.title} ${song.artist} chords site:azchords.com',
      '${song.title} ${song.artist} chords site:guitartabs.cc',
    ];

    // Run searches in parallel
    final tasks = queries.map((q) => _searchAndScrape(q)).toList();
    
    // Add direct search tasks
    tasks.add(_directSearchGuitarTabsCC(song));
    
    // Add Official Lyrics fetch
    // tasks.add(_fetchOfficialLyrics(song));

    // Add Generic Lyric Search (Genius/AZLyrics)
    // tasks.add(_searchAndScrape('${song.title} ${song.artist} lyrics site:genius.com OR site:azlyrics.com'));

    final searchOutputs = await Future.wait(tasks);

    for (var output in searchOutputs) {
      if (output != null && output.length > 50) { // Lower threshold for lyrics
        results.add(output);
      }
    }

    // Fallback logic...
    if (results.isEmpty) {
       print('Site-specific searches failed. Trying generic...');
       final generic = await _searchAndScrape('${song.title} ${song.artist} chords');
       if (generic != null) results.add(generic);
    }

    return results;
  }

  Future<String?> _fetchOfficialLyrics(Song song) async {
    try {
      final url = 'https://api.lyrics.ovh/v1/${Uri.encodeComponent(song.artist)}/${Uri.encodeComponent(song.title)}';
      
      // Use direct fetch (lyrics.ovh supports CORS) instead of proxy, which is being flaky.
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lyrics = data['lyrics'] as String?;
        if (lyrics != null && lyrics.isNotEmpty) {
           return "OFFICIAL LYRICS SOURCE (lyrics.ovh):\n$lyrics";
        }
      }
      return null;
    } catch (e) {
      print('lyrics.ovh failed: $e');
      return null;
    }
  }

  Future<String?> _directSearchGuitarTabsCC(Song song) async {
    try {
      final query = '${song.title} ${song.artist}';
      // Use HTTPS to avoid Android cleartext blocking
      final searchUrl = 'https://www.guitartabs.cc/search.php?fm=off&v=${Uri.encodeComponent(query)}';
      print('GTCC Search: $searchUrl');
      
      final searchResp = await _fetchWithProxy(searchUrl);
      if (searchResp.statusCode != 200) {
        print('GTCC Search Failed: ${searchResp.statusCode}');
        return null;
      }

      final searchDoc = html.parse(searchResp.body);
      final links = searchDoc.querySelectorAll('a');
      String? bestLink;
      
      for (final link in links) {
        final href = link.attributes['href'];
        final text = link.text.toLowerCase();
        
        // Looser matching for songs
        if (href != null && (text.contains('tab') || text.contains('chord'))) {
           print('GTCC: Found candidate: $text -> $href');
           bestLink = href;
           if (!bestLink.startsWith('http')) {
             bestLink = 'https://www.guitartabs.cc$bestLink';
           }
           break; // Take the first relevant result
        }
      }
      
      if (bestLink == null) {
        print('GTCC: No relevant link found in ${links.length} results. First text: ${links.firstOrNull?.text}');
        return null;
      }
      
      print('GTCC: Fetching page: $bestLink');
      final pageResp = await _fetchWithProxy(bestLink);
      if (pageResp.statusCode != 200) return null;
      
      final pageDoc = html.parse(pageResp.body);
      final pre = pageDoc.querySelector('pre');
      if (pre != null) return "Source (guitartabs.cc):\n${pre.text}";
      
      print('GTCC: No <pre> tag found on page');
      return null;

    } catch (e) {
      print('Direct GTCC search failed: $e');
      return null;
    }
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

      final searchDoc = html.parse(searchResp.body);
      // Try multiple result selectors
      final link = searchDoc.querySelector('.result__a')?.attributes['href'] ?? 
                   searchDoc.querySelector('.result__snippet')?.attributes['href'];
      
      if (link == null) {
        print('DDG: No results found for: $query');
        return null;
      }

      // 2. Fetch Page
      var targetLink = link;
      if (link.contains('duckduckgo.com/l/')) {
        final uri = Uri.parse(link.startsWith('//') ? 'https:$link' : link);
        final uddg = uri.queryParameters['uddg'];
        if (uddg != null) {
          targetLink = uddg;
          print('DDG: Decoded redirect -> $targetLink');
        }
      }

      // GUARD: Don't scrape DuckDuckGo itself (ads, y.js, tracking)
      if (targetLink.contains('duckduckgo.com')) {
         print('DDG: Skipping internal/ad link: $targetLink');
         return null;
      }

      print('DDG: Scaping $targetLink');
      final pageResp = await _fetchWithProxy(targetLink);
      if (pageResp.statusCode != 200) {
        print('Page Fetch Failed (${pageResp.statusCode}): $targetLink');
        return null;
      }

      final pageDoc = html.parse(pageResp.body);
      
      // SPECIAL HANDLING: Ultimate-Guitar store config (where the real tab lives)
      if (targetLink.contains('ultimate-guitar.com')) {
         final scripts = pageDoc.querySelectorAll('script');
         for (final script in scripts) {
           if (script.text.contains('content') && script.text.contains('[tab]')) {
             // Try to regex extract the tab content from their JSON store
             final tabMatch = RegExp(r'&quot;content&quot;:&quot;(.*?)&quot;').firstMatch(script.text);
             if (tabMatch != null) {
               String rawVal = tabMatch.group(1) ?? "";
               // Unescape basic chars
               rawVal = rawVal.replaceAll(r'\r\n', '\n').replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
               if (rawVal.length > 50) return "Source (Ultimate-Guitar):\n$rawVal";
             }
           }
         }
      }

      // 3. Extract best content
      // Prioritize <pre> tags (tabs), then specific containers
      final pre = pageDoc.querySelector('js-tab-content') ?? pageDoc.querySelector('pre');
      if (pre != null && pre.text.length > 50) return "Source (${Uri.parse(targetLink).host}):\n${pre.text}";
      
      // Cleanup Body Fallback (Remove Scripts/JSON-LD/Styles)
      pageDoc.querySelectorAll('script').forEach((e) => e.remove());
      pageDoc.querySelectorAll('style').forEach((e) => e.remove());
      pageDoc.querySelectorAll('meta').forEach((e) => e.remove());
      pageDoc.querySelectorAll('link').forEach((e) => e.remove());
      pageDoc.querySelectorAll('noscript').forEach((e) => e.remove());
      
      var bodyText = pageDoc.body?.text.trim() ?? "";
      
      // Post-Processing: Remove lines that look like JSON or CSS
      // Remove lines starting with { or " or . or @
      bodyText = bodyText.split('\n').where((line) {
        final l = line.trim();
        if (l.isEmpty) return false;
        if (l.startsWith('{') || l.startsWith('"') || l.startsWith('.') || l.startsWith('@')) return false;
        if (l.contains('function()')) return false;
        if (l.length < 3) return false; // fast filter noise
        return true;
      }).join('\n');

      return "Source (${Uri.parse(targetLink).host}):\n${bodyText.length > 5000 ? bodyText.substring(0, 5000) : bodyText}";



    } catch (e) {
      print('Scrape error for "$query": $e');
      return null;
    }
  }

  /// Helper to fetch URL with CORS proxy on Web
  Future<http.Response> _fetchWithProxy(String url) async {
    if (!kIsWeb) {
      return http.get(Uri.parse(url), headers: {'User-Agent': 'ChordScan/1.0'});
    }

    // 1. Primary: AllOrigins
    try {
      final target = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
      final response = await http.get(Uri.parse(target));
      if (response.statusCode == 200) return response;
      print('Proxy 1 (AllOrigins) failed: ${response.statusCode}');
    } catch (e) {
      print('Proxy 1 (AllOrigins) error: $e');
    }

    // 2. Secondary: ThingProxy
    try {
      print('Switching to Proxy 2 (ThingProxy)...');
      final target = 'https://thingproxy.freeboard.io/fetch/$url';
      final response = await http.get(Uri.parse(target));
      if (response.statusCode == 200) return response;
      print('Proxy 2 (ThingProxy) failed: ${response.statusCode}');
    } catch (e) {
      print('Proxy 2 (ThingProxy) error: $e');
    }

    // 3. Tertiary: CORSProxy.io (often blocked, but worth a shot)
    try {
      print('Switching to Proxy 3 (CORSProxy)...');
      final target = 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
      return await http.get(Uri.parse(target));
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
