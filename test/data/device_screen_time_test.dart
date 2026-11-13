import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/device_screen_time.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(AndroidUsageScreenTime.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  void answer(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(calls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  final source = AndroidUsageScreenTime();

  group('AndroidUsageScreenTime', () {
    test('asks the platform whether usage access is granted', () async {
      answer((call) => call.method == 'hasUsageAccess');
      expect(await source.hasAccess(), isTrue);
      expect(source.isSupported, isTrue);
    });

    test('opens the usage access settings page', () async {
      answer((_) => null);
      await source.openAccessSettings();
      expect(calls.single.method, 'openUsageAccessSettings');
    });

    test('sends local midnights and maps minutes back to days', () async {
      answer((call) => [95, 0, 240]);

      final minutes = await source.dailyMinutes(
        from: DateTime(2026, 11, 9, 18),
        to: DateTime(2026, 11, 11, 9),
      );

      final args = calls.single.arguments as Map;
      expect(calls.single.method, 'dailyScreenTime');
      expect(args['boundaries'], [
        for (final d in [9, 10, 11, 12])
          DateTime(2026, 11, d).millisecondsSinceEpoch,
      ]);
      // Days with no screen time are left out, like any other missing day.
      expect(minutes, {DateTime(2026, 11, 9): 95, DateTime(2026, 11, 11): 240});
    });

    test('caps each day at 24 hours and drops bad values', () async {
      answer((call) => [5000, -3, 'x']);

      final minutes = await source.dailyMinutes(
        from: DateTime(2026, 11, 9),
        to: DateTime(2026, 11, 11),
      );

      expect(minutes, {DateTime(2026, 11, 9): 24 * 60});
    });

    test('a reply with the wrong number of days is ignored', () async {
      answer((call) => [10]);
      expect(
        await source.dailyMinutes(
          from: DateTime(2026, 11, 9),
          to: DateTime(2026, 11, 11),
        ),
        isEmpty,
      );
    });

    test('platform errors read as no access and no data', () async {
      answer((call) => throw PlatformException(code: 'NO_ACCESS'));
      expect(await source.hasAccess(), isFalse);
      expect(
        await source.dailyMinutes(
          from: DateTime(2026, 11, 9),
          to: DateTime(2026, 11, 9),
        ),
        isEmpty,
      );
    });

    test('a missing native side reads as no access', () async {
      messenger.setMockMethodCallHandler(channel, null);
      expect(await source.hasAccess(), isFalse);
    });

    test('an empty or reversed range never calls the platform', () async {
      answer((call) => [1]);
      expect(
        await source.dailyMinutes(
          from: DateTime(2026, 11, 10),
          to: DateTime(2026, 11, 9),
        ),
        isEmpty,
      );
      expect(calls, isEmpty);
    });
  });

  test('NoDeviceScreenTime is unsupported and empty', () async {
    const none = NoDeviceScreenTime();
    expect(none.isSupported, isFalse);
    expect(await none.hasAccess(), isFalse);
    expect(
      await none.dailyMinutes(from: DateTime(2026), to: DateTime(2026)),
      isEmpty,
    );
  });
}
