import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// #48: a patch-level SDK minimum (e.g. ^3.13.5) breaks `flutter pub get`
// for teammates one patch behind, and patch releases never add language
// features. Require only the minor version.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final sdk = RegExp(
    r'^environment:\s*\n\s+sdk:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspec)?.group(1);

  test('pubspec has an SDK constraint', () => expect(sdk, isNotNull));

  test('the SDK constraint is ^X.Y.0, not a patch minimum', () {
    expect(sdk, matches(RegExp(r'^\^\d+\.\d+\.0$')));
  });

  test('the installed Dart SDK satisfies it', () {
    final min = sdk!.substring(1).split('.').map(int.parse).toList();
    final current = RegExp(r'^(\d+)\.(\d+)\.(\d+)')
        .firstMatch(Platform.version)!;
    final have = [for (var i = 1; i <= 3; i++) int.parse(current.group(i)!)];
    expect(have[0], min[0], reason: 'same major version');
    expect(
      have[1] * 1000 + have[2],
      greaterThanOrEqualTo(min[1] * 1000 + min[2]),
    );
  });
}
