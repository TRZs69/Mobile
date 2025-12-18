import 'package:app/model/levely_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LevelyStorage {
  static const _key = 'levely_progress_v1';

  static Future<LevelyProgress> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return LevelyProgress.empty();
    try {
      return LevelyProgress.fromJsonString(raw);
    } catch (_) {
      return LevelyProgress.empty();
    }
  }

  static Future<void> save(LevelyProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, progress.toJsonString());
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

