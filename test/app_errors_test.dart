import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/app_errors.dart';

void main() {
  late void Function(FlutterErrorDetails)? originalOnError;
  late ErrorWidgetBuilder originalBuilder;
  late bool Function(Object, StackTrace)? originalPlatformOnError;

  setUp(() {
    originalOnError = FlutterError.onError;
    originalBuilder = ErrorWidget.builder;
    originalPlatformOnError =
        WidgetsBinding.instance.platformDispatcher.onError;
  });

  tearDown(() {
    FlutterError.onError = originalOnError;
    ErrorWidget.builder = originalBuilder;
    WidgetsBinding.instance.platformDispatcher.onError =
        originalPlatformOnError;
  });

  test('release builds swap the red error box for a friendly one', () {
    installErrorHandlers(releaseMode: true);

    final widget = ErrorWidget.builder(
      FlutterErrorDetails(exception: StateError('boom')),
    );
    expect(widget, isA<FriendlyErrorBox>());
  });

  test('debug builds keep the default error box', () {
    installErrorHandlers(releaseMode: false);
    expect(ErrorWidget.builder, same(originalBuilder));
  });

  test('uncaught async errors are logged and marked handled', () {
    final logged = <String>[];
    installErrorHandlers(releaseMode: true, log: logged.add);

    final handled = WidgetsBinding.instance.platformDispatcher.onError!(
      StateError('secret 8,000 steps'),
      StackTrace.empty,
    );

    expect(handled, isTrue);
    expect(logged.first, contains('StateError'));
    // Only the type and stack: messages can carry health data.
    expect(logged.join('\n'), isNot(contains('8,000')));
  });

  test('framework errors in release are logged by type only', () {
    final logged = <String>[];
    installErrorHandlers(releaseMode: true, log: logged.add);

    FlutterError.onError!(
      FlutterErrorDetails(exception: ArgumentError('slept 7h 12m')),
    );

    expect(logged.single, contains('ArgumentError'));
    expect(logged.single, isNot(contains('7h 12m')));
  });

  testWidgets('the friendly box renders without a MaterialApp', (
    tester,
  ) async {
    await tester.pumpWidget(const FriendlyErrorBox());
    expect(find.textContaining('Something went wrong'), findsOneWidget);
  });
}
