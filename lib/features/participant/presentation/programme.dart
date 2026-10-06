/// Admin S.No (`sortOrder`). Empty when the session was never numbered.
int? scheduleSortOrder(Map schedule) {
  final raw = schedule['sortOrder'];
  if (raw is int) return raw > 0 ? raw : null;
  if (raw is num) {
    final n = raw.toInt();
    if (n > 0 && n.toDouble() == raw.toDouble()) return n;
  }
  return null;
}

/// Same order as the admin list: calendar day, then S.No, then clock.
int compareParticipantItems(Map<String, dynamic> a, Map<String, dynamic> b) {
  final aStart = a['start'] is DateTime ? a['start'] as DateTime : null;
  final bStart = b['start'] is DateTime ? b['start'] as DateTime : null;
  if (aStart == null && bStart != null) return 1;
  if (aStart != null && bStart == null) return -1;
  if (aStart != null && bStart != null) {
    final day = DateTime(aStart.year, aStart.month, aStart.day)
        .compareTo(DateTime(bStart.year, bStart.month, bStart.day));
    if (day != 0) return day;
  }
  final aSchedule = a['schedule'];
  final bSchedule = b['schedule'];
  final ao = aSchedule is Map ? scheduleSortOrder(aSchedule) : null;
  final bo = bSchedule is Map ? scheduleSortOrder(bSchedule) : null;
  if (ao != null && bo != null && ao != bo) return ao.compareTo(bo);
  if (ao != null && bo == null) return -1;
  if (ao == null && bo != null) return 1;
  if (aStart != null && bStart != null) {
    final aTime = a['hasTime'] == true;
    final bTime = b['hasTime'] == true;
    if (aTime != bTime) return aTime ? -1 : 1;
    final time = aStart.compareTo(bStart);
    if (time != 0) return time;
  }
  final aName = aSchedule is Map
      ? aSchedule['scheduleName']?.toString() ?? ''
      : '';
  final bName = bSchedule is Map
      ? bSchedule['scheduleName']?.toString() ?? ''
      : '';
  return aName.compareTo(bName);
}

String sessionHall(Map<String, dynamic> item) {
  final schedule = item['schedule'];
  if (schedule is! Map) return 'Other';
  final hall = schedule['hall']?.toString().trim() ?? '';
  return hall.isEmpty ? 'Other' : hall;
}

bool isPlaceholderSpeaker(String name) {
  final n = name.trim();
  return n.isEmpty ||
      n == '—' ||
      n == '-' ||
      n.toLowerCase() == 'speaker not listed';
}

/// Panel names are stored joined with " · ". Placeholders such as "—" are dropped.
List<String> splitSpeakerNames(String? raw) {
  final seen = <String>{};
  final names = <String>[];
  for (final part in (raw ?? '').split(' · ')) {
    final name = part.trim();
    if (isPlaceholderSpeaker(name)) continue;
    if (seen.add(name.toLowerCase())) names.add(name);
  }
  return names;
}

String displaySpeaker(String? raw) => splitSpeakerNames(raw).join(' · ');

bool scheduleFlag(Map schedule, String key) => schedule[key] == true;

/// From time shown to a participant. Empty when the admin hid that box.
String visibleFromTime(Map schedule) {
  if (scheduleFlag(schedule, 'hideFromTime')) return '';
  return schedule['fromTime']?.toString().trim() ?? '';
}

/// To time shown to a participant. Empty when the admin hid that box.
String visibleToTime(Map schedule) {
  if (scheduleFlag(schedule, 'hideToTime')) return '';
  return schedule['toTime']?.toString().trim() ?? '';
}

bool scheduleDateVisible(Map schedule) =>
    !scheduleFlag(schedule, 'hideDate') &&
    (schedule['date']?.toString().trim().isNotEmpty ?? false);
