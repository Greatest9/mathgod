import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathgod/screens/solver_screen.dart';

/// Deliberately unsendable per VM pragma. If the isolate message that the
/// solver builds can reach a State's element tree, this becomes reachable and
/// `SendPort.send()` throws "object is unsendable".
@pragma('vm:isolate-unsendable')
class _UnsendableMarker {
  const _UnsendableMarker();
}

class _Marker extends InheritedWidget {
  const _Marker({required this.payload, required super.child});

  final _UnsendableMarker payload;

  @override
  bool updateShouldNotify(_Marker oldWidget) => false;
}

void main() {
  testWidgets('solving does not send widget state to the worker isolate',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: _Marker(
          payload: const _UnsendableMarker(),
          child: const SolverScreen(initialInput: 'd/dx[x^3]'),
        ),
      ),
    );
    await tester.pump();

    // Isolate replies are real async events, which are not delivered inside
    // the widget test's fake-async zone; runAsync lets the round trip finish.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 4));
    });
    await tester.pump();

    expect(
      find.byType(SnackBar),
      findsNothing,
      reason: 'solve surfaced an isolate error instead of a result',
    );
    expect(
      find.byIcon(Icons.share_rounded),
      findsOneWidget,
      reason: 'solve never completed, so the boundary was not really crossed',
    );

    // Unmount and advance the test clock so flutter_animate's one-shot
    // timers fire instead of being reported as pending at teardown.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
