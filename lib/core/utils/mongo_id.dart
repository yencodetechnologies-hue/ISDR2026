/// Parses Mongo-style `id` / `_id` from JSON (plain string or extended `{"$oid":"..."}`).
String parseMongoId(dynamic value) {
  if (value == null) return '';
  if (value is String) {
    final s = value.trim();
    return s;
  }
  if (value is Map) {
    final oid = value[r'$oid'];
    if (oid is String) return oid.trim();
  }
  return '';
}
