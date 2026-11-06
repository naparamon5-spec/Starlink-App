import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starlink_app/features/auth/change_password.dart';
import 'package:starlink_app/shared/widgets/unsaved_changes_guard.dart';

/// A home page with a button that opens [page].
Widget _host(Widget page) => MaterialApp(
  home: Builder(
    builder:
        (context) => Scaffold(
          body: TextButton(
            onPressed:
                () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => page)),
            child: const Text('open'),
          ),
        ),
  ),
);

Future<void> _open(WidgetTester t, Widget page) async {
  await t.pumpWidget(_host(page));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

void main() {
  group('FormBaseline', () {
    test('values loaded before it is ready are not changes', () {
      final b = FormBaseline();
      expect(b.changed(ready: false, values: ['']), isFalse);
      expect(b.changed(ready: true, values: ['Ramon']), isFalse);
      expect(b.changed(ready: true, values: ['Ramon!']), isTrue);
      expect(b.changed(ready: true, values: ['Ramon']), isFalse);
    });
  });

  group('Change Password page', () {
    testWidgets('leaves without asking when nothing was typed', (t) async {
      await _open(t, const AdminChangePasswordPage());
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('asks when typed; Keep editing stays, Discard leaves', (
      t,
    ) async {
      await _open(t, const AdminChangePasswordPage());
      await t.enterText(find.byType(TextField).first, 'secret');
      await t.pump();

      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);

      await t.tap(find.text('Keep editing'));
      await t.pumpAndSettle();
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('secret'), findsOneWidget);

      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      await t.tap(find.text('Discard'));
      await t.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('clearing the field again means nothing to discard', (t) async {
      await _open(t, const AdminChangePasswordPage());
      await t.enterText(find.byType(TextField).first, 'secret');
      await t.pump();
      await t.enterText(find.byType(TextField).first, '');
      await t.pump();
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  testWidgets('leaving after a save does not ask', (t) async {
    await _open(
      t,
      Builder(
        builder:
            (context) => UnsavedChangesGuard(
              isDirty: () => true,
              child: Scaffold(
                appBar: AppBar(),
                // What a page does once its save succeeds.
                body: TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('saved'),
                ),
              ),
            ),
      ),
    );
    await t.tap(find.text('saved'));
    await t.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
