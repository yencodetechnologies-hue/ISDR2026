import 'dart:convert';

/// Normalizes Dio [data] to a JSON object map when possible.
Map<String, dynamic>? asJsonMap(dynamic data) {
  if (data == null) return null;
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  if (data is String) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return null;
}

/// Reads API `error` field without throwing when [data] is a List/String.
String? errorMessageFromData(dynamic data) {
  final map = asJsonMap(data);
  if (map == null) return null;
  final err = map['error'];
  if (err == null) return null;
  return err.toString();
}
