import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/ui/app_shell.dart';
import '../../../../shared/ui/section_card.dart';
import '../../plugin_providers.dart';

class DiagnosticsPage extends ConsumerWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(pluginControllerProvider);

    return AppShell(
      title: 'Diagnostics',
      subtitle:
          'Review plugin parse status, compatibility warnings, and runtime log excerpts.',
      child: snapshot.when(
        data: (data) {
          if (data.plugins.isEmpty) {
            return const SectionCard(
              child: Center(
                child: Text('No plugin diagnostics available yet.'),
              ),
            );
          }

          return ListView.separated(
            itemCount: data.plugins.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final plugin = data.plugins[index];
              final diagnostics = plugin.diagnostics;
              return SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            plugin.displayName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Text(diagnostics?.status.name ?? 'unknown'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(diagnostics?.message ?? 'No message'),
                    if (diagnostics?.requiredPackages.isNotEmpty ??
                        false) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        'Required packages: ${diagnostics!.requiredPackages.join(', ')}',
                      ),
                    ],
                    if (diagnostics?.missingPackages.isNotEmpty ??
                        false) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'Unsupported shims: ${diagnostics!.missingPackages.join(', ')}',
                      ),
                    ],
                    const SizedBox(height: 12),
                    SelectableText(
                      (diagnostics?.logs.isNotEmpty ?? false)
                          ? diagnostics!.logs.join('\n')
                          : 'No runtime logs captured yet.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          );
        },
        error: (error, _) => SectionCard(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
