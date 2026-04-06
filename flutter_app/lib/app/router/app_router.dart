import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/discover/presentation/pages/discover_page.dart';
import '../../features/discover/presentation/pages/recommend_sheets_page.dart';
import '../../features/media/domain/media_route_state.dart';
import '../../features/media/presentation/pages/album_detail_page.dart';
import '../../features/media/presentation/pages/artist_detail_page.dart';
import '../../features/media/presentation/pages/music_detail_page.dart';
import '../../features/media/presentation/pages/music_sheet_page.dart';
import '../../features/media/presentation/pages/sheet_detail_page.dart';
import '../../features/media/presentation/pages/toplist_detail_page.dart';
import '../../features/plugins/presentation/pages/diagnostics_page.dart';
import '../../features/plugins/presentation/pages/downloads_page.dart';
import '../../features/plugins/presentation/pages/local_music_page.dart';
import '../../features/plugins/presentation/pages/overview_page.dart';
import '../../features/plugins/presentation/pages/plugin_detail_page.dart';
import '../../features/plugins/presentation/pages/plugins_page.dart';
import '../../features/plugins/presentation/pages/recently_played_page.dart';
import '../../features/plugins/presentation/pages/settings_page.dart';
import '../../features/plugins/presentation/pages/subscriptions_page.dart';
import '../../features/search/presentation/pages/search_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/search',
    routes: <RouteBase>[
      GoRoute(
        path: '/overview',
        builder: (context, state) => const OverviewPage(),
      ),
      GoRoute(
        path: '/recently-played',
        builder: (context, state) => const RecentlyPlayedPage(),
      ),
      GoRoute(
        path: '/downloads',
        builder: (context, state) => const DownloadsPage(),
      ),
      GoRoute(
        path: '/local-music',
        builder: (context, state) => const LocalMusicPage(),
      ),
      GoRoute(
        path: '/plugins',
        builder: (context, state) => const PluginsPage(),
      ),
      GoRoute(
        path: '/discover',
        builder: (context, state) => const DiscoverPage(),
      ),
      GoRoute(
        path: '/recommend-sheets',
        builder: (context, state) => const RecommendSheetsPage(),
      ),
      GoRoute(path: '/search', builder: (context, state) => const SearchPage()),
      GoRoute(
        path: '/music',
        builder: (context, state) =>
            MusicDetailPage(state: state.extra! as MusicRouteState),
      ),
      GoRoute(
        path: '/album',
        builder: (context, state) =>
            AlbumDetailPage(state: state.extra! as AlbumRouteState),
      ),
      GoRoute(
        path: '/sheet',
        builder: (context, state) =>
            SheetDetailPage(state: state.extra! as SheetRouteState),
      ),
      GoRoute(
        path: '/music-sheet/:pluginId/:sheetId',
        builder: (context, state) {
          final pluginId = state.pathParameters['pluginId'] ?? '';
          final sheetId = state.pathParameters['sheetId'] ?? '';
          return MusicSheetPage(pluginId: pluginId, sheetId: sheetId);
        },
      ),
      GoRoute(
        path: '/artist',
        builder: (context, state) =>
            ArtistDetailPage(state: state.extra! as ArtistRouteState),
      ),
      GoRoute(
        path: '/toplist',
        builder: (context, state) =>
            TopListDetailPage(state: state.extra! as TopListRouteState),
      ),
      GoRoute(
        path: '/plugins/:pluginId',
        builder: (context, state) {
          final pluginId = state.pathParameters['pluginId'] ?? '';
          return PluginDetailPage(pluginId: pluginId);
        },
      ),
      GoRoute(
        path: '/subscriptions',
        builder: (context, state) => const SubscriptionsPage(),
      ),
      GoRoute(
        path: '/diagnostics',
        builder: (context, state) => const DiagnosticsPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});
