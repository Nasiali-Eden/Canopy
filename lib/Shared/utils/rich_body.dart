// Helpers for coercing a stored `body` field into displayable text.
//
// A `body` may be persisted as:
//   • a String — the current article editor's markdown-ish format
//     (`# `, `## `, `### ` heading prefixes, newline-separated), or plain text
//     for announcements / broadcasts;
//   • a List of block maps — older / seeded article documents, where each block
//     looks like `{ 'type': 'h1'|'h2'|'h3'|'paragraph', 'text': '...' }`;
//   • a single Map block, or null.
//
// These functions accept any of those shapes (never throw on a type mismatch)
// so callers can drop the unsafe `data['body'] as String?` cast.

String _blockText(Map block) =>
    (block['text'] ?? block['content'] ?? block['value'] ?? '').toString();

/// Coerces [raw] to a newline-separated string that preserves heading markers
/// (`#`/`##`/`###`). Non-destructive — a plain String is returned unchanged, so
/// it is safe for announcement bodies too. Use for full-article rendering,
/// re-editing, or any display that already understands newlines.
String richBodyToMarkdown(dynamic raw) {
  if (raw is String) return raw;
  if (raw is Map) return _blockText(raw);
  if (raw is List) {
    return raw.map((b) {
      if (b is! Map) return b.toString();
      final text = _blockText(b);
      switch ((b['type'] ?? '').toString().toLowerCase()) {
        case 'h1':
        case 'heading1':
          return '# $text';
        case 'h2':
        case 'heading2':
          return '## $text';
        case 'h3':
        case 'heading3':
          return '### $text';
        default:
          return text;
      }
    }).join('\n');
  }
  return '';
}

/// Coerces [raw] to a single line of plain text — heading markers stripped and
/// newlines flattened to spaces. Use for previews / card snippets.
String richBodyToPlainText(dynamic raw) {
  return richBodyToMarkdown(raw)
      .replaceAll(RegExp(r'(?:^|\n)#{1,3}\s*'), ' ')
      .replaceAll('\n', ' ')
      .trim();
}
