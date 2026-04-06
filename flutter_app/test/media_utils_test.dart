import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/media/media_constants.dart';
import 'package:flutter_app/core/media/media_utils.dart';

void main() {
  group('media_utils', () {
    test('resetMediaItem rewrites platform and removes internal data', () {
      final item = <String, dynamic>{
        'platform': 'old',
        'id': '1',
        'title': 'Track',
        internalDataKey: <String, dynamic>{'cache': true},
      };

      final normalized = resetMediaItem(
        item,
        platform: 'new_platform',
        clone: true,
      );

      expect(normalized['platform'], 'new_platform');
      expect(normalized.containsKey(internalDataKey), isFalse);
      expect(item.containsKey(internalDataKey), isTrue);
    });

    test('resetMediaItem keeps local plugin items unchanged', () {
      final item = <String, dynamic>{'platform': localPluginName, 'id': '1'};

      final normalized = resetMediaItem(
        item,
        platform: localPluginName,
        clone: true,
      );

      expect(normalized['platform'], localPluginName);
      expect(normalized['id'], '1');
    });

    test('getMediaPrimaryKey matches legacy platform@id format', () {
      expect(
        getMediaPrimaryKey(<String, dynamic>{'platform': 'qq', 'id': '123'}),
        'qq@123',
      );
    });
  });
}
