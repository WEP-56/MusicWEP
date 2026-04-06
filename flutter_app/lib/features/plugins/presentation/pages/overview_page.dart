import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app/app_environment_provider.dart';
import '../../../../shared/ui/app_shell.dart';
import '../../../../shared/ui/section_card.dart';
import '../../plugin_providers.dart';

class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(pluginControllerProvider);
    final appEnvironment = ref.watch(appEnvironmentProvider);

    return AppShell(
      title: 'Overview',
      subtitle:
          'Windows-first plugin workspace with a shared runtime path for Android.',
      child: appEnvironment.when(
        data: (environment) => snapshot.when(
          data: (data) {
            final total = data.plugins.length;
            final enabled = data.plugins
                .where((plugin) => plugin.meta.enabled)
                .length;
            final failed = data.plugins
                .where((plugin) => plugin.diagnostics?.status.name == 'error')
                .length;
            final warnings = data.plugins
                .where((plugin) => plugin.diagnostics?.status.name == 'warning')
                .length;
            return ListView(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _StatCard(
                        label: 'Installed plugins',
                        value: '$total',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(label: 'Enabled', value: '$enabled'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(label: 'Errors', value: '$failed'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(label: 'Warnings', value: '$warnings'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Runtime target',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _InfoLine(
                        label: 'Platform',
                        value: environment.platform.name,
                      ),
                      _InfoLine(
                        label: 'Runtime OS',
                        value: environment.runtimeOs,
                      ),
                      _InfoLine(label: 'Version', value: environment.version),
                      _InfoLine(label: 'Build', value: environment.buildNumber),
                      _InfoLine(
                        label: 'Language',
                        value: environment.languageTag,
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
                        'Delivery order',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      const Text('1. Windows desktop validation'),
                      const SizedBox(height: 8),
                      const Text('2. Shared domain/application reuse'),
                      const SizedBox(height: 8),
                      const Text(
                        '3. Android shell integration after Windows runtime is stable',
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          error: (error, _) => SectionCard(child: Text(error.toString())),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => SectionCard(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
        ],
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
