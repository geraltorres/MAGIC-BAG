import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_provider.g.dart';

@riverpod
class ThemeControl extends _$ThemeControl {
  @override
  ThemeMode build() => ThemeMode.system;

  void toggleTheme() {
    state = (state == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
  }
}
