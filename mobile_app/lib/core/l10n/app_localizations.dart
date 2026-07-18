import 'package:flutter/material.dart';
import 'package:bustan_amari/core/l10n/strings_ar.dart';
import 'package:bustan_amari/core/l10n/strings_en.dart';

class AppLocalizations {
  final Locale locale;
  late final Map<String, String> _strings;

  /// Statically accessible instance for non-widget code.
  static AppLocalizations _current = AppLocalizations(const Locale('ar'));
  static AppLocalizations get current => _current;

  /// Supported locales; order matters — first is the default.
  static const supportedLocales = [Locale('ar'), Locale('en')];

  AppLocalizations(this.locale) {
    _strings = locale.languageCode == 'en' ? stringsEn : stringsAr;
  }

  /// Retrieve the nearest [AppLocalizations] from the widget tree.
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        _current;
  }

  /// Look up a translated string by [key].
  /// Returns the key itself if not found (fail-safe).
  String tr(String key) => _strings[key] ?? key;

  /// Look up a string and replace `{0}` with [arg].
  /// Useful for interpolated messages like "try again in {0} minutes".
  String trArgs(String key, String arg) {
    final value = _strings[key] ?? key;
    return value.replaceAll('{0}', arg);
  }

  /// Whether the current locale is RTL.
  bool get isRtl => locale.languageCode == 'ar';

  /// Delegate for [MaterialApp.localizationsDelegates].
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

/// Custom [LocalizationsDelegate] that loads [AppLocalizations].
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    // Update the static instance so non-widget code stays in sync.
    AppLocalizations._current = localizations;
    return localizations;
  }

  @override
  bool shouldReload(covariant _AppLocalizationsDelegate old) => false;
}
