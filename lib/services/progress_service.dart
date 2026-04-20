import 'package:shared_preferences/shared_preferences.dart';

class ProgressSnippet {
  const ProgressSnippet({required this.storageKey, required this.label});

  final String storageKey;
  final String label;
}

class ProgressService {
  static const String _studyKey = 'progress.study';
  static const String _practiceKey = 'progress.practice';
  static const String _notesKey = 'progress.notes';

  static const List<ProgressSnippet> snippets = [
    ProgressSnippet(storageKey: _studyKey, label: 'Estudié 20 minutos'),
    ProgressSnippet(
      storageKey: _practiceKey,
      label: 'Hice el ejercicio práctico',
    ),
    ProgressSnippet(
      storageKey: _notesKey,
      label: 'Anoté una reflexión breve',
    ),
  ];

  String labelForKey(String storageKey) {
    for (final snippet in snippets) {
      if (snippet.storageKey == storageKey) {
        return snippet.label;
      }
    }
    return storageKey;
  }

  Future<Map<String, bool>> loadSnippets() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final snippet in snippets)
        snippet.storageKey: prefs.getBool(snippet.storageKey) ?? false,
    };
  }

  Future<void> saveSnippet(String storageKey, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(storageKey, value);
  }

  int completionPercent(Map<String, bool> snippets) {
    if (snippets.isEmpty) {
      return 0;
    }

    final completed = snippets.values.where((item) => item).length;
    return ((completed / snippets.length) * 100).round();
  }
}
