import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/ui/app_shell.dart';
import '../../../../shared/ui/section_card.dart';
import '../../domain/plugin.dart';
import '../../domain/plugin_capability.dart';
import '../../plugin_providers.dart';

class PluginDetailPage extends ConsumerWidget {
  const PluginDetailPage({super.key, required this.pluginId});

  final String pluginId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(pluginControllerProvider);

    return AppShell(
      title: 'Plugin details',
      subtitle: 'Inspect exported metadata and compatibility diagnostics.',
      child: snapshot.when(
        data: (data) {
          final plugin = data.plugins
              .where((entry) => entry.storageKey == pluginId)
              .cast<PluginRecord?>()
              .firstOrNull;
          if (plugin == null) {
            return const SectionCard(child: Text('Plugin not found.'));
          }
          return ListView(
            children: <Widget>[
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      plugin.displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    _InfoLine(label: 'Hash', value: plugin.hash),
                    _InfoLine(
                      label: 'Version',
                      value: plugin.version ?? 'Unknown',
                    ),
                    _InfoLine(
                      label: 'Source URL',
                      value: plugin.sourceUrl ?? 'Not provided',
                    ),
                    _InfoLine(label: 'File path', value: plugin.filePath),
                    _InfoLine(
                      label: 'Enabled',
                      value: plugin.meta.enabled ? 'Yes' : 'No',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Capabilities',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          plugin.manifest?.supportedMethods
                              .map(
                                (entry) => Chip(
                                  label: Text(
                                    PluginCapability.fromMethod(entry)?.label ??
                                        entry,
                                  ),
                                ),
                              )
                              .toList(growable: false) ??
                          const <Widget>[Text('No exported methods detected.')],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _UserVariablesSection(plugin: plugin),
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Diagnostics',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _InfoLine(
                      label: 'Status',
                      value: plugin.diagnostics?.status.name ?? 'Unknown',
                    ),
                    _InfoLine(
                      label: 'Message',
                      value: plugin.diagnostics?.message ?? 'No message',
                    ),
                    _InfoLine(
                      label: 'Checked at',
                      value:
                          plugin.diagnostics?.checkedAt.toIso8601String() ??
                          'Unknown',
                    ),
                    _InfoLine(
                      label: 'Required packages',
                      value:
                          plugin.diagnostics?.requiredPackages.isNotEmpty ==
                              true
                          ? plugin.diagnostics!.requiredPackages.join(', ')
                          : 'None',
                    ),
                    _InfoLine(
                      label: 'Missing package shims',
                      value:
                          plugin.diagnostics?.missingPackages.isNotEmpty == true
                          ? plugin.diagnostics!.missingPackages.join(', ')
                          : 'None',
                    ),
                    if (plugin.diagnostics?.stackTrace != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(plugin.diagnostics!.stackTrace!),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
        error: (error, _) => SectionCard(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          SelectableText(value),
        ],
      ),
    );
  }
}

class _UserVariablesSection extends ConsumerStatefulWidget {
  const _UserVariablesSection({required this.plugin});

  final PluginRecord plugin;

  @override
  ConsumerState<_UserVariablesSection> createState() =>
      _UserVariablesSectionState();
}

class _UserVariablesSectionState extends ConsumerState<_UserVariablesSection> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  bool _saving = false;
  String? _savedMessage;

  @override
  void initState() {
    super.initState();
    _hydrateControllers();
  }

  @override
  void didUpdateWidget(covariant _UserVariablesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plugin.storageKey != widget.plugin.storageKey) {
      _disposeControllers();
      _hydrateControllers();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _hydrateControllers() {
    final definitions = widget.plugin.manifest?.userVariables ?? const [];
    final persisted = widget.plugin.meta.userVariables;
    for (final definition in definitions) {
      final key = definition.key;
      if (key.isEmpty) continue;
      _controllers[key] = TextEditingController(text: persisted[key] ?? '');
    }
  }

  void _disposeControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _savedMessage = null;
    });
    try {
      final values = <String, String>{
        for (final entry in _controllers.entries) entry.key: entry.value.text,
      };
      await ref
          .read(pluginControllerProvider.notifier)
          .updateUserVariables(widget.plugin, values);
      if (!mounted) return;
      setState(() => _savedMessage = 'Saved.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _savedMessage = 'Failed: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final definitions = widget.plugin.manifest?.userVariables ?? const [];
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'User variables',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (definitions.isEmpty)
            const Text('No user variables declared.')
          else
            ...definitions.map((definition) {
              final key = definition.key;
              if (key.isEmpty) return const SizedBox.shrink();
              final controller = _controllers[key] ??= TextEditingController(
                text: widget.plugin.meta.userVariables[key] ?? '',
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      definition.name?.trim().isNotEmpty == true
                          ? '${definition.name} ($key)'
                          : key,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: definition.hint,
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (definitions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
                const SizedBox(width: 12),
                if (_savedMessage != null)
                  Text(
                    _savedMessage!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
