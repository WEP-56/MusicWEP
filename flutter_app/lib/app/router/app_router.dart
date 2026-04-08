import 'package:flutter/material.dart';
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
import '../../shared/ui/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/discover',
    routes: <RouteBase>[
      ShellRoute(
        builder: (context, state, child) {
          if (child is AppShell) {
            return AppShellScaffold(
              title: child.title,
              subtitle: child.subtitle,
              actions: child.actions,
              child: child.child,
            );
          }
          return AppShellScaffold(title: '', subtitle: '', child: child);
        },
        routes: <RouteBase>[
          _shellPageRoute(
            path: '/overview',
            builder: (context, state) => const OverviewPage(),
          ),
          _shellPageRoute(
            path: '/recently-played',
            builder: (context, state) => const RecentlyPlayedPage(),
          ),
          _shellPageRoute(
            path: '/downloads',
            builder: (context, state) => const DownloadsPage(),
          ),
          _shellPageRoute(
            path: '/local-music',
            builder: (context, state) => const LocalMusicPage(),
          ),
          _shellPageRoute(
            path: '/plugins',
            builder: (context, state) => const PluginsPage(),
          ),
          _shellPageRoute(
            path: '/discover',
            builder: (context, state) => const DiscoverPage(),
          ),
          _shellPageRoute(
            path: '/recommend-sheets',
            builder: (context, state) => const RecommendSheetsPage(),
          ),
          _shellPageRoute(
            path: '/search',
            builder: (context, state) => const SearchPage(),
          ),
          _detailPageRoute(
            path: '/music',
            builder: (context, state) =>
                MusicDetailPage(state: state.extra! as MusicRouteState),
          ),
          _detailPageRoute(
            path: '/album',
            builder: (context, state) =>
                AlbumDetailPage(state: state.extra! as AlbumRouteState),
          ),
          _detailPageRoute(
            path: '/sheet',
            builder: (context, state) =>
                SheetDetailPage(state: state.extra! as SheetRouteState),
          ),
          _detailPageRoute(
            path: '/music-sheet/:pluginId/:sheetId',
            builder: (context, state) {
              final pluginId = state.pathParameters['pluginId'] ?? '';
              final sheetId = state.pathParameters['sheetId'] ?? '';
              return MusicSheetPage(pluginId: pluginId, sheetId: sheetId);
            },
          ),
          _detailPageRoute(
            path: '/artist',
            builder: (context, state) =>
                ArtistDetailPage(state: state.extra! as ArtistRouteState),
          ),
          _detailPageRoute(
            path: '/toplist',
            builder: (context, state) =>
                TopListDetailPage(state: state.extra! as TopListRouteState),
          ),
          _detailPageRoute(
            path: '/plugins/:pluginId',
            builder: (context, state) {
              final pluginId = state.pathParameters['pluginId'] ?? '';
              return PluginDetailPage(pluginId: pluginId);
            },
          ),
          _shellPageRoute(
            path: '/subscriptions',
            builder: (context, state) => const SubscriptionsPage(),
          ),
          _shellPageRoute(
            path: '/diagnostics',
            builder: (context, state) => const DiagnosticsPage(),
          ),
          _shellPageRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );
});

GoRoute _shellPageRoute({
  required String path,
  required Widget Function(BuildContext, GoRouterState) builder,
}) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => NoTransitionPage<void>(
      key: state.pageKey,
      child: builder(context, state),
    ),
  );
}

GoRoute _detailPageRoute({
  required String path,
  required Widget Function(BuildContext, GoRouterState) builder,
}) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: builder(context, state),
      transitionDuration: const Duration(milliseconds: 140),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(opacity: curve, child: child);
      },
    ),
  );
}
