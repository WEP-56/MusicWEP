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
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'User variables',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (plugin.manifest?.userVariables.isEmpty ?? true)
                      const Text('No user variables declared.')
                    else
                      ...plugin.manifest!.userVariables.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                item.name?.trim().isNotEmpty == true
                                    ? '${item.name} (${item.key})'
                                    : item.key,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              if (item.hint?.trim().isNotEmpty ==
                                  true) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(item.hint!),
                              ],
                            ],
                          ),
                        ),
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
