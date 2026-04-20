import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {
  static const String _studyKey = 'progress.study';
  static const String _practiceKey = 'progress.practice';
  static const String _notesKey = 'progress.notes';

  Future<Map<String, bool>> loadSnippets() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'Estudié 20 minutos': prefs.getBool(_studyKey) ?? false,
      'Hice el ejercicio práctico': prefs.getBool(_practiceKey) ?? false,
      'Anoté una reflexión breve': prefs.getBool(_notesKey) ?? false,
    };
  }

  Future<void> saveSnippet(String label, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    switch (label) {
      case 'Estudié 20 minutos':
        await prefs.setBool(_studyKey, value);
        break;
      case 'Hice el ejercicio práctico':
        await prefs.setBool(_practiceKey, value);
        break;
      case 'Anoté una reflexión breve':
        await prefs.setBool(_notesKey, value);
        break;
    }
  }

  int completionPercent(Map<String, bool> snippets) {
    if (snippets.isEmpty) {
      return 0;
    }

    final completed = snippets.values.where((item) => item).length;
    return ((completed / snippets.length) * 100).round();
  }
}
