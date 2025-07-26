// lib/settings_service.dart

import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  // Singleton patterni ile her zaman aynı nesnenin kullanılmasını sağlıyoruz.
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;

  // Servisi başlatmak için kullanılacak
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Eşik Değerleri ---

  // Varsayılan değerler
  static const double _defaultMinValue = 1.0;
  static const double _defaultMaxValue = 4.0;

  // Kaydedilmiş minimum değeri getirir, yoksa varsayılanı döndürür.
  double getMinValue() {
    return _prefs.getDouble('minValue') ?? _defaultMinValue;
  }

  // Yeni minimum değeri kaydeder.
  Future<void> setMinValue(double value) async {
    await _prefs.setDouble('minValue', value);
  }

  // Kaydedilmiş maksimum değeri getirir, yoksa varsayılanı döndürür.
  double getMaxValue() {
    return _prefs.getDouble('maxValue') ?? _defaultMaxValue;
  }

  // Yeni maksimum değeri kaydeder.
  Future<void> setMaxValue(double value) async {
    await _prefs.setDouble('maxValue', value);
  }
}
