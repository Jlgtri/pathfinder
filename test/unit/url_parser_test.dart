import 'package:flutter_test/flutter_test.dart';

import '../../lib/src/providers.dart';

void main() {
  group('parseUrl', () {
    test('accepts a full HTTPS API URL and preserves query parameters', () {
      final Uri? parsed = parseUrl(
        '  https://flutter.webspark.dev/flutter/api?token=abc&limit=3  ',
      );
      expect(parsed, isNotNull);
      expect(parsed!.scheme, 'https');
      expect(parsed.host, 'flutter.webspark.dev');
      expect(parsed.queryParameters, <String, String>{
        'token': 'abc',
        'limit': '3',
      });
    });

    test('accepts localhost with a development port', () {
      expect(parseUrl('http://localhost:8080/webspark'), isNotNull);
      expect(parseUrl('http://127.0.0.1:3000/api'), isNotNull);
    });

    test('rejects missing schemes, credentials, fragments, whitespace', () {
      for (final String value in <String>[
        '',
        'flutter.webspark.dev/api',
        'ftp://example.com',
        'https://user:secret@example.com/api',
        'https://example.com/api#fragment',
        'https://example.com/path with spaces',
        'https://example..com/api',
        'https://-example.com/api',
        'https://example.com/%GG',
      ]) {
        expect(
          parseUrl(value),
          isNull,
          reason: 'Unexpectedly accepted: $value',
        );
      }
    });
  });
}
