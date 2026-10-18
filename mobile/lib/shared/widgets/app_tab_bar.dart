import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_context.dart';
import '../theme/app_tone.dart';
import '../theme/app_typography.dart';

/// One place in [AppTabBar]: an icon, or a short piece of text drawn as one
/// (the Sounds tab's ሀ), and a label.
class AppTab {
  const AppTab({required this.label, this.icon, this.glyph, this.key})
    : assert(icon != null || glyph != null);

  final String label;
  final IconData? icon;

  /// Shown in place of an icon, such as a script's first letter.
  final String? glyph;
  final Key? key;
}

/// A page of tabs: [body] over [bar], with the bar kept above the phone's
/// own bar and the body's pages each drawing their own [AppPage].
class AppTabFrame extends StatelessWidget {
  const AppTabFrame({super.key, required this.body, required this.bar});

  final Widget body;
  final AppTabBar bar;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: body, bottomNavigationBar: bar);
}

/// The bottom bar of the signed-in app: small icons, each with its label
/// always shown, the current one tinted. Sits above the phone's own bar.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.tabs,
    required this.current,
    required this.onSelect,
  });

  final List<AppTab> tabs;
  final int current;
  final ValueChanged<int> onSelect;

  static const double height = 62;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: colors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: height),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space2xs,
            ),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _TabButton(
                      key: tabs[i].key,
                      tab: tabs[i],
                      selected: i == current,
                      onTap: () => onSelect(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    super.key,
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = context.tone(AppTone.secondary);
    final ink = selected ? tone.ink : colors.onSurfaceVariant;
    final glyph = tab.glyph;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.space2xs + 2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 48,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? tone.surface : null,
                  borderRadius: BorderRadius.circular(AppRadii.sm + 2),
                  border: selected
                      ? Border.all(color: tone.border, width: 1.5)
                      : null,
                ),
                child: glyph != null
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          glyph,
                          style: AppTypography.labelLg.copyWith(
                            color: ink,
                            fontSize: 17,
                            height: 1.1,
                            letterSpacing: 0,
                          ),
                        ),
                      )
                    : Icon(tab.icon, size: 22, color: ink),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tab.label,
                  maxLines: 1,
                  style: AppTypography.labelSm.copyWith(
                    color: ink,
                    letterSpacing: 0,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
