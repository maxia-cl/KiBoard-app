import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the user chose in Settings, kept across launches.
///
/// A `ValueNotifier` rather than a state package: three values, read from two screens, and the app
/// already rebuilds from streams everywhere else. `load()` runs before `runApp` so the first frame
/// is already in the right language — a deck that flashes English and then turns Spanish is worse
/// than one that takes 5 ms longer to appear.
class Settings extends ValueNotifier<SettingsData> {
  Settings._() : super(const SettingsData());

  static final instance = Settings._();

  static const _kHaptics = 'haptics';
  static const _kSound = 'sound';
  static const _kLocale = 'locale'; // '' = follow the phone

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = SettingsData(
      haptics: prefs.getBool(_kHaptics) ?? true,
      sound: prefs.getBool(_kSound) ?? true,
      languageCode: prefs.getString(_kLocale) ?? '',
    );
  }

  Future<void> setHaptics(bool on) async {
    value = value.copyWith(haptics: on);
    (await SharedPreferences.getInstance()).setBool(_kHaptics, on);
  }

  Future<void> setSound(bool on) async {
    value = value.copyWith(sound: on);
    (await SharedPreferences.getInstance()).setBool(_kSound, on);
  }

  /// '' means follow the phone, which is the default and what most people want: they already told
  /// Android what language they read in.
  Future<void> setLanguage(String code) async {
    value = value.copyWith(languageCode: code);
    (await SharedPreferences.getInstance()).setString(_kLocale, code);
  }
}

@immutable
class SettingsData {
  final bool haptics;
  final bool sound;
  final String languageCode;

  const SettingsData({this.haptics = true, this.sound = true, this.languageCode = ''});

  SettingsData copyWith({bool? haptics, bool? sound, String? languageCode}) => SettingsData(
    haptics: haptics ?? this.haptics,
    sound: sound ?? this.sound,
    languageCode: languageCode ?? this.languageCode,
  );
}
