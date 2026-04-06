import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../plugins/domain/plugin.dart';
import '../plugins/domain/plugin_search.dart';
import '../plugins/plugin_providers.dart';

class SearchPageState {
  const SearchPageState({
    required this.query,
    required this.type,
    required this.pluginId,
    required this.page,
    required this.result,
  });

  final String query;
  final PluginSearchType type;
  final String? pluginId;
  final int page;
  final PluginSearchResult? result;

  factory SearchPageState.initial() {
    return const SearchPageState(
      query: '',
      type: PluginSearchType.music,
      pluginId: null,
      page: 1,
      result: null,
    );
  }
}

class SearchPageController extends AsyncNotifier<SearchPageState> {
  @override
  Future<SearchPageState> build() async {
    return SearchPageState.initial();
  }

  Future<void> search({
    required PluginRecord plugin,
    required String query,
    required PluginSearchType type,
    int page = 1,
    bool append = false,
  }) async {
    final previous = state.valueOrNull ?? SearchPageState.initial();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = await ref.read(pluginMethodServiceProvider.future);
      final result = await service.searchSinglePlugin(
        plugin: plugin,
        query: query,
        type: type,
        page: page,
      );
      final mergedResult = append && previous.result != null
          ? PluginSearchResult(
              plugin: result!.plugin,
              items: <PluginSearchResultItem>[
                ...previous.result!.items,
                ...result.items,
              ],
              logs: result.logs,
              requiredPackages: result.requiredPackages,
              missingPackages: result.missingPackages,
              isEnd: result.isEnd,
              errorMessage: result.errorMessage,
            )
          : result;

      return SearchPageState(
        query: query,
        type: type,
        pluginId: plugin.storageKey,
        page: page,
        result: mergedResult,
      );
    });
  }
}

final searchPageControllerProvider =
    AsyncNotifierProvider<SearchPageController, SearchPageState>(
      SearchPageController.new,
    );
