import 'package:flutter/material.dart';

import '../services/appearance_repository.dart';

/// The learner's Appearance choice, app-wide (022-light-and-dark-themes,
/// story 006): the app's [MaterialApp] draws in [value], and setting it
/// redraws every screen at once and keeps the choice on the phone.
class AppearanceController extends ValueNotifier<ThemeMode> {
  AppearanceController({
    required this._repository,
    ThemeMode initial = ThemeMode.system,
  }) : super(initial);

  /// A controller starting from the stored choice, read before the first
  /// frame so a Light choice on a dark phone never flashes dark.
  static Future<AppearanceController> load(
    AppearanceRepository repository,
  ) async => AppearanceController(
    repository: repository,
    initial: await repository.load(),
  );

  final AppearanceRepository _repository;

  /// Applies [mode] at once and keeps it.
  Future<void> choose(ThemeMode mode) async {
    value = mode;
    await _repository.save(mode);
  }
}

/// Hands the [AppearanceController] down the tree, as [Theme] does the
/// theme, so Settings can reach it without every screen passing it on.
class AppearanceScope extends InheritedNotifier<AppearanceController> {
  const AppearanceScope({
    super.key,
    required AppearanceController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The nearest controller, or `null` where the app provides none (a
  /// screen pumped on its own in a test).
  static AppearanceController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()?.notifier;
}
