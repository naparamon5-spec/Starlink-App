import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starlink_app/shared/widgets/app_dialog.dart';

void main() {
  late BuildContext ctx;

  Future<void> open(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const Scaffold();
          },
        ),
      ),
    );
  }

  Future<bool?> ask(WidgetTester t, String tap) async {
    await open(t);
    bool? answer;
    showAppConfirm(
      ctx,
      title: 'Send reset link?',
      message: 'A link will be emailed.',
      confirmLabel: 'Send',
      icon: Icons.mail_outline_rounded,
    ).then((v) => answer = v);
    await t.pumpAndSettle();
    expect(find.text('Send reset link?'), findsOneWidget);
    expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
    await t.tap(find.text(tap));
    await t.pumpAndSettle();
    expect(find.text('Send reset link?'), findsNothing);
    return answer;
  }

  testWidgets('the main button answers true', (t) async {
    expect(await ask(t, 'Send'), isTrue);
  });

  testWidgets('Cancel answers false', (t) async {
    expect(await ask(t, 'Cancel'), isFalse);
  });

  testWidgets('tapping outside answers false', (t) async {
    await open(t);
    bool? answer;
    showAppConfirm(
      ctx,
      title: 'Sure?',
      message: 'Really.',
      confirmLabel: 'Yes',
      icon: Icons.help_outline,
    ).then((v) => answer = v);
    await t.pumpAndSettle();
    await t.tapAt(const Offset(4, 4));
    await t.pumpAndSettle();
    expect(answer, isFalse);
  });

  testWidgets('long labels and text fit a small phone', (t) async {
    t.view.physicalSize = const Size(320, 560);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await open(t);
    showAppConfirm(
      ctx,
      title: 'Discard changes to this very long named thing?',
      message: List.filled(60, 'Your changes will be lost.').join(' '),
      confirmLabel: 'Close this ticket forever',
      cancelLabel: 'Keep editing this one',
      icon: Icons.edit_off_outlined,
      tone: AppDialogTone.danger,
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('a null onConfirm disables the main button', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: AppDialog(
          icon: Icons.task_alt_rounded,
          title: 'Resolve ticket',
          confirmLabel: 'Resolve',
          onConfirm: null,
        ),
      ),
    );
    expect(
      t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
