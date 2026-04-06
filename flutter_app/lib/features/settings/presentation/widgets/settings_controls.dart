import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../shared/ui/section_card.dart';

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class SettingsChoiceChipBar<T> extends StatelessWidget {
  const SettingsChoiceChipBar({
    super.key,
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.onChanged,
  });

  final T value;
  final List<T> options;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options
          .map(
            (entry) => ChoiceChip(
              label: Text(labelBuilder(entry)),
              selected: entry == value,
              onSelected: (_) => onChanged(entry),
            ),
          )
          .toList(growable: false),
    );
  }
}

class SettingsField extends StatelessWidget {
  const SettingsField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.labelLarge),
          if (hint?.trim().isNotEmpty == true) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class SettingsPathField extends StatelessWidget {
  const SettingsPathField({
    super.key,
    required this.path,
    required this.onChanged,
  });

  final String path;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: SelectableText(
            path,
            maxLines: 2,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: () async {
            final selected = await FilePicker.platform.getDirectoryPath(
              dialogTitle: '选择目录',
            );
            if (selected == null || selected.trim().isEmpty) {
              return;
            }
            onChanged(selected);
          },
          child: const Text('选择目录'),
        ),
      ],
    );
  }
}

class SettingsPlaceholder extends StatelessWidget {
  const SettingsPlaceholder({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsSectionCard(
      title: title,
      children: <Widget>[
        Text(
          description,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
