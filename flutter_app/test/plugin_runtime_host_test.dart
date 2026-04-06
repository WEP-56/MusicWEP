import 'package:flutter_test/flutter_test.dart';
import 'package:pub_semver/pub_semver.dart';

void main() {
  group('runtime validation heuristics', () {
    test('recognizes common legacy package names from sample plugins', () {
      const script = '''
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const axios_1 = require("axios");
const cheerio_1 = require("cheerio");
const CryptoJS = require("crypto-js");
const dayjs = require("dayjs");
module.exports = {
  platform: "Audiomack",
  version: "0.1.0",
  srcUrl: "https://example.com/plugins/audiomack.js",
  async search(query, page, type) {
    return { isEnd: true, data: [] };
  },
  async getLyric() {
    return null;
  }
};
''';

      final requiredPackages = RegExp(
        r'''require\(["']([^"']+)["']\)''',
      ).allMatches(script).map((match) => match.group(1)!).toSet();
      final supportedPackages = <String>{
        'axios',
        'cheerio',
        'crypto-js',
        'dayjs',
        'big-integer',
        'qs',
        'he',
        'webdav',
        '@react-native-cookies/cookies',
      };

      expect(requiredPackages.difference(supportedPackages), isEmpty);
      expect(script, contains('platform: "Audiomack"'));
      expect(
        script,
        contains('srcUrl: "https://example.com/plugins/audiomack.js"'),
      );
    });

    test('flags unsupported package names in inspection heuristics', () {
      const script = '''
const leftPad = require("left-pad");
module.exports = {
  platform: "UnsupportedDeps",
  srcUrl: "https://example.com/plugins/unsupported.js",
  async search() {
    return { isEnd: true, data: [] };
  }
};
''';

      final requiredPackages = RegExp(
        r'''require\(["']([^"']+)["']\)''',
      ).allMatches(script).map((match) => match.group(1)!).toSet();
      final supportedPackages = <String>{
        'axios',
        'cheerio',
        'crypto-js',
        'dayjs',
        'big-integer',
        'qs',
        'he',
        'webdav',
        '@react-native-cookies/cookies',
      };

      expect(requiredPackages.difference(supportedPackages), {'left-pad'});
      expect(script, contains('platform: "UnsupportedDeps"'));
    });

    test('checks appVersion constraints used by plugin compatibility', () {
      final constraint = VersionConstraint.parse('>9.0.0');
      final currentVersion = Version.parse('0.1.0');

      expect(constraint.allows(currentVersion), isFalse);
    });
  });
}
