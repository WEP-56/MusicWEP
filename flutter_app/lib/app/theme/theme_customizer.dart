import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import 'app_theme.dart';
import 'theme_controller.dart';

class ThemeCustomizerPane extends ConsumerStatefulWidget {
  const ThemeCustomizerPane({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<ThemeCustomizerPane> createState() =>
      _ThemeCustomizerPaneState();
}

class _ThemeCustomizerPaneState extends ConsumerState<ThemeCustomizerPane> {
  late final TextEditingController _nameController;

  bool _editorVisible = false;
  bool _saving = false;
  String? _editingThemeId;
  double _hue = 0;
  double _saturation = 0;
  double _value = 0;
  String? _selectedBackgroundSourcePath;
  AppThemeBackgroundData? _existingBackground;
  bool _clearBackground = false;

  Color get _editorColor =>
      HSVColor.fromAHSV(1, _hue, _saturation, _value).toColor();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(appThemeControllerProvider).valueOrNull ??
        AppThemeSettings.defaults;
    final controller = ref.read(appThemeControllerProvider.notifier);
    final colors = AppTheme.colorsOf(context);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('主题外观', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '可以切换显示模式、预设主题，并创建多个带命名的自定义主题。自定义主题支持图片、GIF 和 MP4 视频背景。',
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
          Text('预设主题', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: AppThemePreset.values
                .map(
                  (preset) => _ThemePresetTile(
                    label: preset.label,
                    seedColor: preset.seedColor,
                    selected: settings.activeThemeId == preset.id,
                    compact: widget.compact,
                    onTap: () => controller.setTheme(preset.id),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '自定义主题',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('新建主题'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (settings.customThemes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: const Text('还没有自定义主题，点击“新建主题”即可创建。'),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: settings.customThemes
                  .map(
                    (theme) => _CustomThemeTile(
                      theme: theme,
                      selected: settings.activeThemeId == theme.id,
                      compact: widget.compact,
                      onTap: () => controller.setTheme(theme.id),
                      onEdit: () => _openEditor(theme: theme),
                      onDelete: () => _deleteTheme(controller, theme),
                    ),
                  )
                  .toList(growable: false),
            ),
          if (_editorVisible) ...<Widget>[
            const SizedBox(height: 18),
            _CustomThemeEditor(
              nameController: _nameController,
              color: _editorColor,
              hue: _hue,
              saturation: _saturation,
              value: _value,
              backgroundLabel: _backgroundLabel,
              backgroundTypeLabel: _backgroundTypeLabel,
              hasExistingBackground: _existingBackground != null,
              hasPendingBackgroundSelection:
                  _selectedBackgroundSourcePath?.trim().isNotEmpty == true,
              clearBackground: _clearBackground,
              saving: _saving,
              onHueChanged: (value) => setState(() => _hue = value),
              onSaturationChanged: (value) =>
                  setState(() => _saturation = value),
              onValueChanged: (value) => setState(() => _value = value),
              onPickBackground: _pickBackground,
              onClearBackground: () {
                setState(() {
                  _selectedBackgroundSourcePath = null;
                  _clearBackground = true;
                });
              },
              onCancel: () {
                setState(() {
                  _editorVisible = false;
                  _selectedBackgroundSourcePath = null;
                  _clearBackground = false;
                });
              },
              onSave: () => _saveCustomTheme(controller),
            ),
          ],
        ],
      ),
    );
  }

  String get _backgroundLabel {
    if (_selectedBackgroundSourcePath != null) {
      return path.basename(_selectedBackgroundSourcePath!);
    }
    if (_clearBackground) {
      return '已移除背景';
    }
    if (_existingBackground != null) {
      return path.basename(_existingBackground!.relativePath);
    }
    return '未选择背景';
  }

  String get _backgroundTypeLabel {
    final selectedType = _selectedBackgroundSourcePath == null
        ? null
        : AppThemeBackgroundType.fromPath(_selectedBackgroundSourcePath!);
    if (selectedType != null) {
      return selectedType.label;
    }
    return _existingBackground?.type.label ?? '无背景';
  }

  void _openEditor({AppCustomThemeData? theme}) {
    final seedColor = theme?.seedColor ?? AppThemePreset.sunset.seedColor;
    final hsvColor = HSVColor.fromColor(seedColor);
    setState(() {
      _editorVisible = true;
      _saving = false;
      _editingThemeId = theme?.id;
      _nameController.text = theme?.name ?? '';
      _hue = hsvColor.hue;
      _saturation = hsvColor.saturation;
      _value = hsvColor.value;
      _selectedBackgroundSourcePath = null;
      _existingBackground = theme?.background;
      _clearBackground = false;
    });
  }

  Future<void> _pickBackground() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择背景图片、GIF 或 MP4',
      type: FileType.custom,
      allowedExtensions: const <String>[
        'png',
        'jpg',
        'jpeg',
        'webp',
        'bmp',
        'gif',
        'mp4',
        'mov',
        'mkv',
        'webm',
      ],
    );
    final selectedPath = result?.files.singleOrNull?.path;
    if (selectedPath == null || selectedPath.trim().isEmpty) {
      return;
    }

    setState(() {
      _selectedBackgroundSourcePath = selectedPath;
      _clearBackground = false;
    });
  }

  Future<void> _saveCustomTheme(ThemeController controller) async {
    setState(() {
      _saving = true;
    });

    try {
      await controller.saveCustomTheme(
        themeId: _editingThemeId,
        name: _nameController.text,
        seedColor: _editorColor,
        backgroundSourcePath: _selectedBackgroundSourcePath,
        clearBackground: _clearBackground,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _editorVisible = false;
        _selectedBackgroundSourcePath = null;
        _clearBackground = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('自定义主题保存失败：$error')));
    }
  }

  Future<void> _deleteTheme(
    ThemeController controller,
    AppCustomThemeData theme,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除自定义主题'),
          content: Text('确认删除“${theme.name}”吗？相关背景资源也会一并移除。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await controller.deleteCustomTheme(theme.id);
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
    required this.label,
    required this.seedColor,
    required this.selected,
    required this.compact,
    required this.onTap,
    this.icon,
    this.helperText,
  });

  final String label;
  final Color seedColor;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;
  final IconData? icon;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 108.0 : 128.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? seedColor.withValues(alpha: 0.12)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? seedColor : Theme.of(context).dividerColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _ColorDot(color: seedColor),
                const SizedBox(width: 6),
                _ColorDot(
                  color: Color.alphaBlend(
                    seedColor.withValues(alpha: 0.35),
                    Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                _ColorDot(
                  color: Color.alphaBlend(
                    seedColor.withValues(alpha: 0.55),
                    Colors.black,
                  ),
                ),
                const Spacer(),
                if (icon != null)
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? seedColor : Theme.of(context).hintColor,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? seedColor : null,
              ),
            ),
            if (helperText != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                helperText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected
                      ? seedColor.withValues(alpha: 0.88)
                      : Theme.of(context).hintColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomThemeTile extends StatelessWidget {
  const _CustomThemeTile({
    required this.theme,
    required this.selected,
    required this.compact,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final AppCustomThemeData theme;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final helperText = switch (theme.background?.type) {
      AppThemeBackgroundType.image => '图片 / GIF',
      AppThemeBackgroundType.video => '视频背景',
      null => '纯配色',
    };
    return Stack(
      children: <Widget>[
        _ThemePresetTile(
          label: theme.name,
          seedColor: theme.seedColor,
          selected: selected,
          compact: compact,
          icon: switch (theme.background?.type) {
            AppThemeBackgroundType.image => Icons.image_rounded,
            AppThemeBackgroundType.video => Icons.video_collection_rounded,
            null => Icons.palette_rounded,
          },
          helperText: helperText,
          onTap: onTap,
        ),
        Positioned(
          top: 4,
          right: 4,
          child: PopupMenuButton<_CustomThemeAction>(
            tooltip: '主题操作',
            icon: const Icon(Icons.more_horiz_rounded, size: 18),
            onSelected: (value) {
              switch (value) {
                case _CustomThemeAction.edit:
                  onEdit();
                case _CustomThemeAction.delete:
                  onDelete();
              }
            },
            itemBuilder: (context) =>
                const <PopupMenuEntry<_CustomThemeAction>>[
                  PopupMenuItem<_CustomThemeAction>(
                    value: _CustomThemeAction.edit,
                    child: Text('编辑'),
                  ),
                  PopupMenuItem<_CustomThemeAction>(
                    value: _CustomThemeAction.delete,
                    child: Text('删除'),
                  ),
                ],
          ),
        ),
      ],
    );
  }
}

enum _CustomThemeAction { edit, delete }

class _CustomThemeEditor extends StatelessWidget {
  const _CustomThemeEditor({
    required this.nameController,
    required this.color,
    required this.hue,
    required this.saturation,
    required this.value,
    required this.backgroundLabel,
    required this.backgroundTypeLabel,
    required this.hasExistingBackground,
    required this.hasPendingBackgroundSelection,
    required this.clearBackground,
    required this.saving,
    required this.onHueChanged,
    required this.onSaturationChanged,
    required this.onValueChanged,
    required this.onPickBackground,
    required this.onClearBackground,
    required this.onCancel,
    required this.onSave,
  });

  final TextEditingController nameController;
  final Color color;
  final double hue;
  final double saturation;
  final double value;
  final String backgroundLabel;
  final String backgroundTypeLabel;
  final bool hasExistingBackground;
  final bool hasPendingBackgroundSelection;
  final bool clearBackground;
  final bool saving;
  final ValueChanged<double> onHueChanged;
  final ValueChanged<double> onSaturationChanged;
  final ValueChanged<double> onValueChanged;
  final Future<void> Function() onPickBackground;
  final VoidCallback onClearBackground;
  final VoidCallback onCancel;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('编辑自定义主题', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: '主题名称',
              hintText: '例如：初音夜景 / 暖调海报',
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _colorHex(color),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SliderField(
            label: 'Hue',
            value: hue,
            max: 360,
            onChanged: onHueChanged,
          ),
          _SliderField(
            label: 'Saturation',
            value: saturation,
            max: 1,
            onChanged: onSaturationChanged,
          ),
          _SliderField(
            label: 'Value',
            value: value,
            max: 1,
            onChanged: onValueChanged,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text('背景资源', style: theme.textTheme.labelLarge),
                    ),
                    TextButton.icon(
                      onPressed: saving ? null : () => onPickBackground(),
                      icon: const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 18,
                      ),
                      label: const Text('选择文件'),
                    ),
                    TextButton.icon(
                      onPressed:
                          saving ||
                              (!hasExistingBackground &&
                                  !hasPendingBackgroundSelection &&
                                  !clearBackground)
                          ? null
                          : onClearBackground,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('移除'),
                    ),
                  ],
                ),
                Text(backgroundLabel, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  '类型：$backgroundTypeLabel',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '保存时会自动复制到应用目录，不依赖原始文件路径。',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '大图、GIF 或 MP4 可能增加内存与 GPU 占用，建议自行选择合适素材。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: saving ? null : onCancel,
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: saving ? null : () => onSave(),
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存主题'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _colorHex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('$label  ${value.toStringAsFixed(max == 1 ? 2 : 0)}'),
        Slider(value: value.clamp(0, max), max: max, onChanged: onChanged),
      ],
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

extension<T> on List<T> {
  T? get singleOrNull => length == 1 ? first : null;
}
