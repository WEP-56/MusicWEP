import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/audio_player_adapter.dart';
import 'infrastructure/media_kit_player_adapter.dart';

final audioPlayerAdapterProvider = Provider<AudioPlayerAdapter>((ref) {
  return MediaKitPlayerAdapter();
});
