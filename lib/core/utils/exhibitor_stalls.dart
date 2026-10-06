/// Groups exhibitors into A Stall, B Stall, and so on using the location code.
class StallGroup {
  StallGroup(this.title, this.items);

  final String title;
  final List<Map<String, dynamic>> items;
}

class _StallRank {
  const _StallRank(this.letter, this.number, this.code, this.title);

  final String letter;
  final int number;
  final String code;
  final String title;
}

_StallRank _stallRank(Object? location) {
  final raw = (location?.toString() ?? '').trim().toUpperCase();
  final match = RegExp(r'^([A-Z])\s*(\d+)').firstMatch(raw);
  if (match == null) {
    return _StallRank('\uffff', 9999, raw, 'Other');
  }
  final letter = match.group(1)!;
  final number = int.parse(match.group(2)!);
  return _StallRank(letter, number, '$letter$number', '$letter Stall');
}

String stallCode(Object? location) => _stallRank(location).code;

List<StallGroup> stallGroups(List<Map<String, dynamic>> items) {
  final sorted = [...items]..sort((a, b) {
      final left = _stallRank(a['location']);
      final right = _stallRank(b['location']);
      final byLetter = left.letter.compareTo(right.letter);
      if (byLetter != 0) return byLetter;
      return left.number.compareTo(right.number);
    });
  final groups = <StallGroup>[];
  for (final item in sorted) {
    final title = _stallRank(item['location']).title;
    if (groups.isNotEmpty && groups.last.title == title) {
      groups.last.items.add(item);
    } else {
      groups.add(StallGroup(title, [item]));
    }
  }
  return groups;
}
