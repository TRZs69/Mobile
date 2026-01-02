class LevelyRag {
  static const int _defaultMaxSnippets = 3;
  static const int _defaultMaxChars = 1200;

  static String buildSnippet({
    required String material,
    required String query,
    int maxSnippets = _defaultMaxSnippets,
    int maxChars = _defaultMaxChars,
  }) {
    final cleaned = _stripHtml(material);
    if (cleaned.isEmpty) return '';

    final tokens = _tokenize(query);
    final segments = _segment(cleaned);
    if (segments.isEmpty) return '';

    final scored = <({String text, int score})>[];
    for (final seg in segments) {
      final score = _scoreSegment(seg, tokens);
      scored.add((text: seg, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final hasSignal = scored.isNotEmpty && scored.first.score > 0;
    final selected = hasSignal ? scored : _fallbackSegments(segments);

    final snippetLines = <String>[];
    for (final item in selected.take(maxSnippets)) {
      final trimmed = _truncate(item.text.trim(), 320);
      if (trimmed.isNotEmpty) {
        snippetLines.add('- $trimmed');
      }
    }

    final snippet = snippetLines.join('\n');
    if (snippet.length <= maxChars) return snippet;
    return _truncate(snippet, maxChars);
  }

  static String _stripHtml(String input) {
    var text = input;
    text = text.replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</\s*p\s*>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  static List<String> _segment(String text) {
    final paragraphs = text
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.length >= 40)
        .toList();

    if (paragraphs.length >= 3) return paragraphs;

    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.length >= 20)
        .toList();
    if (sentences.isEmpty) return paragraphs;

    final chunks = <String>[];
    var buffer = '';
    var count = 0;
    for (final sentence in sentences) {
      if (buffer.isEmpty) {
        buffer = sentence;
      } else {
        buffer = '$buffer $sentence';
      }
      count++;
      if (count >= 2 || buffer.length >= 240) {
        chunks.add(buffer);
        buffer = '';
        count = 0;
      }
    }
    if (buffer.isNotEmpty) {
      chunks.add(buffer);
    }
    return chunks.isEmpty ? paragraphs : chunks;
  }

  static int _scoreSegment(String segment, List<String> tokens) {
    if (tokens.isEmpty) return 0;
    final lower = segment.toLowerCase();
    var score = 0;
    for (final t in tokens) {
      if (lower.contains(t)) score++;
    }
    return score;
  }

  static List<({String text, int score})> _fallbackSegments(List<String> segments) {
    return segments
        .take(_defaultMaxSnippets)
        .map((s) => (text: s, score: 0))
        .toList();
  }

  static List<String> _tokenize(String text) {
    final lower = text.toLowerCase();
    final raw = lower.split(RegExp(r'[^a-z0-9]+'));
    final stopwords = <String>{
      'yang',
      'dan',
      'atau',
      'dari',
      'ke',
      'di',
      'untuk',
      'pada',
      'dengan',
      'itu',
      'ini',
      'jadi',
      'akan',
      'dalam',
      'sebagai',
      'apa',
      'bagaimana',
      'jelaskan',
      'ringkas',
      'contoh',
      'bisa',
      'tolong',
      'mohon',
    };
    return raw.where((t) => t.length >= 3 && !stopwords.contains(t)).toList();
  }

  static String _truncate(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars).trim()}...';
  }
}
