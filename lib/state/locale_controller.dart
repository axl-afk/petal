import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

class LocaleController extends StateNotifier<Locale?> {
  final Ref _ref;

  LocaleController(this._ref)
      : super(_fromCode(_ref.read(prefsServiceProvider).loadLanguageCode()));

  Future<void> setLanguage(String? code) async {
    state = _fromCode(code);
    await _ref.read(prefsServiceProvider).saveLanguageCode(code);
  }

  static Locale? _fromCode(String? code) =>
      code == null || code.isEmpty ? null : Locale(code);
}

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale?>(
  (ref) => LocaleController(ref),
);
