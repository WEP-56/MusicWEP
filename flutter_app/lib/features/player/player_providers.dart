import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/player_controller.dart';
import 'domain/player_state.dart';

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerState>(PlayerController.new);
