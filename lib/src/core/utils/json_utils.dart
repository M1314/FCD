import 'dart:convert';

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  return <String, dynamic>{};
}

List<dynamic> asList(dynamic value) {
  if (value is List) {
    return value;
  }
  return <dynamic>[];
}

dynamic readFirst(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) {
      return json[key];
    }
  }
  return null;
}

String readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  final value = readFirst(json, keys);
  if (value == null) {
    return fallback;
  }
  if (value is String) {
    return value.trim();
  }
  return value.toString().trim();
}

int readInt(Map<String, dynamic> json, List<String> keys, {int fallback = 0}) {
  final value = readFirst(json, keys);
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

double readDouble(
  Map<String, dynamic> json,
  List<String> keys, {
  double fallback = 0,
}) {
  final value = readFirst(json, keys);
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

bool readBool(
  Map<String, dynamic> json,
  List<String> keys, {
  bool fallback = false,
}) {
  final value = readFirst(json, keys);
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.toLowerCase().trim();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
    return fallback;
  }
  return fallback;
}

List<dynamic> decodeJsonArray(dynamic source) {
  if (source is List) {
    return source;
  }

  if (source is String) {
    if (source.trim().isEmpty) {
      return <dynamic>[];
    }
    try {
      final decoded = jsonDecode(source);
      if (decoded is List) {
        return decoded;
      }
    } catch (_) {
      return <dynamic>[];
    }
  }

  return <dynamic>[];
}
