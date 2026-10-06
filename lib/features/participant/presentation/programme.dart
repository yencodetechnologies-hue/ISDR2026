/// Halls in scientific-programme order. Any other hall follows these.
const programmeHalls = [
  'Dr J G Kannappan Hall',
  'Dr M Rahmatullah Hall',
  'Dr C V Subbarao Hall',
  'SBDCH Auditorium',
  'SBDCH Auditorium Lecture Hall 4',
  'SBDCH Auditorium Halls 1–7',
  'E-Poster Presentations',
];

int programmeHallRank(String hall) {
  final i = programmeHalls.indexOf(hall);
  return i < 0 ? programmeHalls.length : i;
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
