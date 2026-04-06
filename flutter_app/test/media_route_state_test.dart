import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/media/media_models.dart';
import 'package:flutter_app/features/media/domain/media_route_state.dart';

void main() {
  group('media route state equality', () {
    test(
      'recommend sheets route state is stable for identical plugin and tag',
      () {
        const left = RecommendSheetsRouteState(
          pluginId: 'plugin-a',
          tag: MediaTag(id: 'default', name: '默认'),
        );
        const right = RecommendSheetsRouteState(
          pluginId: 'plugin-a',
          tag: MediaTag(id: 'default', name: '别名'),
        );

        expect(left, right);
        expect(left.hashCode, right.hashCode);
      },
    );

    test('sheet route state compares by plugin and sheet identity', () {
      const left = SheetRouteState(
        pluginId: 'plugin-a',
        sheetItem: MusicSheetItem(platform: 'remote', id: '42', title: 'Sheet'),
      );
      const right = SheetRouteState(
        pluginId: 'plugin-a',
        sheetItem: MusicSheetItem(
          platform: 'remote',
          id: '42',
          title: 'Sheet Copy',
        ),
      );

      expect(left, right);
      expect(left.hashCode, right.hashCode);
    });
  });
}
