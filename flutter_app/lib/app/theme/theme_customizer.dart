import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';
import 'theme_controller.dart';

class ThemeCustomizerPane extends ConsumerWidget {
  const ThemeCustomizerPane({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(appThemeControllerProvider).valueOrNull ??
        AppThemeSettings.defaults;
    final controller = ref.read(appThemeControllerProvider.notifier);
    final colors = AppTheme.colorsOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('主题外观', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          '衣架入口现在用于切换主题色和明暗模式。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        Text('显示模式', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _ThemeModeChip(
              label: '浅色',
              icon: Icons.light_mode_rounded,
              selected: settings.mode == ThemeMode.light,
              accent: colors.accent,
              onTap: () => controller.setMode(ThemeMode.light),
            ),
            _ThemeModeChip(
              label: '深色',
              icon: Icons.dark_mode_rounded,
              selected: settings.mode == ThemeMode.dark,
              accent: colors.accent,
              onTap: () => controller.setMode(ThemeMode.dark),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('主题色', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: AppThemePreset.values
              .map(
                (preset) => _ThemePresetTile(
                  preset: preset,
                  selected: preset.id == settings.presetId,
                  compact: compact,
                  onTap: () => controller.setPreset(preset.id),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _ThemeModeChip extends StatelessWidget {
  const _ThemeModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.14)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.7)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 18,
              color: selected ? accent : Theme.of(context).iconTheme.color,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? accent : null,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePresetTile extends StatelessWidget {
  const _ThemePresetTile({
    required this.preset,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final AppThemePreset preset;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 92.0 : 108.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? preset.seedColor.withValues(alpha: 0.12)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? preset.seedColor : Theme.of(context).dividerColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _ColorDot(color: preset.seedColor),
                const SizedBox(width: 6),
                _ColorDot(
                  color: Color.alphaBlend(
                    preset.seedColor.withValues(alpha: 0.35),
                    Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                _ColorDot(
                  color: Color.alphaBlend(
                    preset.seedColor.withValues(alpha: 0.55),
                    Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              preset.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? preset.seedColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
