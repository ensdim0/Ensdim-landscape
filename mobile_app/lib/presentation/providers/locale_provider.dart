import 'package:flutter/material.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/infrastructure/storage/secure_storage_service.dart';

/// Manages the active locale and persists the user's language choice.
///
/// Notifies listeners on change so the entire widget tree rebuilds
/// with the new language — including text direction (RTL ↔ LTR).
class LocaleProvider extends ChangeNotifier {
  final SecureStorageService _storage;

  Locale _locale = _resolveDeviceLocale();
  Locale get locale => _locale;

  /// Whether the current locale is right-to-left.
  bool get isRtl => _locale.languageCode == 'ar';

  LocaleProvider(this._storage);

  static Locale _resolveDeviceLocale() {
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    if (code == 'ar') return const Locale('ar');
    return const Locale('en');
  }

  /// Loads the persisted locale from secure storage.
  /// If nothing is saved, falls back to device locale.
  Future<void> loadSavedLocale() async {
    final saved = await _storage.getLocale();
    if (saved != null &&
        AppLocalizations.supportedLocales.any((l) => l.languageCode == saved)) {
      _locale = Locale(saved);
    } else {
      _locale = _resolveDeviceLocale();
    }
    notifyListeners();
  }

  /// Switches to the given [locale] and persists the choice.
  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    await _storage.saveLocale(locale.languageCode);
    notifyListeners();
  }

  /// Toggles between Arabic and English.
  Future<void> toggleLocale() async {
    final next = _locale.languageCode == 'ar'
        ? const Locale('en')
        : const Locale('ar');
    await setLocale(next);
  }
}
