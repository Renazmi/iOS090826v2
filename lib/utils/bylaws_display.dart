enum BylawsDisplayKind { article, section, heading, label, paragraph }

class BylawsDisplayBlock {
  const BylawsDisplayBlock({required this.kind, required this.text});

  final BylawsDisplayKind kind;
  final String text;
}

List<BylawsDisplayBlock> parseBylawsDisplayBlocks(String body) {
  final blocks = <BylawsDisplayBlock>[];
  for (final raw in body.replaceAll('\r\n', '\n').split('\n')) {
    final line = raw.replaceAll('\u00a0', ' ').trim();
    if (line.isEmpty) continue;
    blocks.add(BylawsDisplayBlock(kind: _classify(line), text: line));
  }
  return blocks;
}

BylawsDisplayKind _classify(String line) {
  if (RegExp(r'^ARTICLE\s+[IVXLCDM\d]+', caseSensitive: false).hasMatch(line)) {
    return BylawsDisplayKind.article;
  }
  if (RegExp(r'^Section\s+\d+', caseSensitive: false).hasMatch(line)) {
    return BylawsDisplayKind.section;
  }
  if (RegExp(r'^\d+\.\d+(\.\d+)?\s+\S').hasMatch(line)) return BylawsDisplayKind.label;
  if (RegExp(r'^[IVXLCDM]+\.\s+\S').hasMatch(line)) return BylawsDisplayKind.label;
  if (RegExp(r'^[a-z]\.\s+\S').hasMatch(line)) return BylawsDisplayKind.paragraph;
  if (RegExp(r'^CONSTITUTION AND BY-LAWS', caseSensitive: false).hasMatch(line)) {
    return BylawsDisplayKind.heading;
  }
  if (_isAllCapsHeading(line)) return BylawsDisplayKind.heading;
  if (RegExp(r'^\d+\.\s+\S').hasMatch(line) && line.length < 160) {
    return BylawsDisplayKind.label;
  }
  return BylawsDisplayKind.paragraph;
}

bool _isAllCapsHeading(String line) {
  if (line.length < 3 || line.length > 90) return false;
  final letters = line.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (letters.length < 3) return false;
  return letters == letters.toUpperCase();
}
