import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../core/storage/json_file_store.dart';
import '../plugins/plugin_providers.dart';
import 'application/player_session_repository.dart';

final playerSessionRepositoryProvider = FutureProvider<PlayerSessionRepository>(
  (ref) async {
    final appPaths = await ref.watch(appPathsProvider.future);
    return PlayerSessionRepository(
      JsonFileStore(
        path.join(appPaths.appDataDirectory.path, 'player_session.json'),
      ),
    );
  },
);
