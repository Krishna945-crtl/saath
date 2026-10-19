import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saath/api/api_client.dart';
import 'package:saath/widgets/state_views.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('offline error shows wifi icon and retries', (tester) async {
    var retried = 0;
    await tester.pumpWidget(wrap(ErrorView(
      error: const ApiException(null, 'timeout'),
      onRetry: () => retried++,
    )));

    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    expect(find.textContaining("Couldn't reach Saath"), findsOneWidget);

    await tester.tap(find.text('Try again'));
    expect(retried, 1);
  });

  testWidgets('server errors never show raw 500 details', (tester) async {
    await tester.pumpWidget(wrap(ErrorView(
      error: const ApiException(500, 'Traceback (most recent call last)...'),
      onRetry: () {},
    )));

    expect(find.textContaining('Traceback'), findsNothing);
    expect(find.textContaining('on our side'), findsOneWidget);
  });
}
