import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starlink_app/shared/widgets/app_toast.dart';

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

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    await t.pump();
  }

  testWidgets('it is a centered dialog that stays until OK', (t) async {
    await open(t);
    AppToast.success(ctx, 'Saved');
    await settle(t);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(
      t.getCenter(find.byType(Dialog)),
      t.getCenter(find.byType(Scaffold)),
    );

    await t.pump(const Duration(seconds: 30));
    expect(find.text('Saved'), findsOneWidget);

    await t.tap(find.text('OK'));
    await settle(t);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('each kind has its own title', (t) async {
    await open(t);
    AppToast.error(ctx, 'No connection');
    await settle(t);
    expect(find.text('Something went wrong'), findsOneWidget);
    await t.tap(find.text('OK'));
    await settle(t);

    AppToast.info(ctx, 'Heads up');
    await settle(t);
    expect(find.text('Notice'), findsOneWidget);
    await t.tap(find.text('OK'));
    await settle(t);
  });

  testWidgets('a new message replaces the current one', (t) async {
    await open(t);
    AppToast.success(ctx, 'One');
    await settle(t);
    AppToast.error(ctx, 'Two');
    await settle(t);
    expect(find.text('One'), findsNothing);
    expect(find.text('Two'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    await t.tap(find.text('OK'));
    await settle(t);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('it shows above a slide-up sheet', (t) async {
    await open(t);
    showModalBottomSheet<void>(
      context: ctx,
      builder: (_) => const SizedBox(height: 200, child: Text('Sheet')),
    );
    await t.pumpAndSettle();
    AppToast.error(ctx, 'Over the sheet');
    await settle(t);
    await t.tap(find.text('OK'));
    await settle(t);
    expect(find.text('Over the sheet'), findsNothing);
    expect(find.text('Sheet'), findsOneWidget);
  });

  testWidgets('a page that closes right after reporting still closes', (
    t,
  ) async {
    await open(t);
    Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder:
            (page) => TextButton(
              onPressed: () {
                AppToast.success(page, 'Created');
                Navigator.pop(page);
              },
              child: const Text('Save'),
            ),
      ),
    );
    await t.pumpAndSettle();

    await t.tap(find.text('Save'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Save'), findsNothing);
    expect(find.text('Created'), findsOneWidget);

    await t.tap(find.text('OK'));
    await settle(t);
    expect(find.text('Created'), findsNothing);
  });

  testWidgets('it survives the page that raised it closing', (t) async {
    await open(t);
    final toast = AppToast.of(ctx);
    await t.pumpWidget(const MaterialApp(home: SizedBox()));
    toast.showSuccess('Still here');
    await t.pump();
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('an action runs and closes the message', (t) async {
    await open(t);
    var undone = false;
    AppToast.info(
      ctx,
      'Removed',
      actionLabel: 'Undo',
      onAction: () => undone = true,
    );
    await settle(t);
    await t.tap(find.text('Undo'));
    await settle(t);
    expect(undone, isTrue);
    expect(find.text('Removed'), findsNothing);
  });

  testWidgets('an action can be declined', (t) async {
    await open(t);
    var undone = false;
    AppToast.info(
      ctx,
      'Removed',
      actionLabel: 'Undo',
      onAction: () => undone = true,
    );
    await settle(t);
    await t.tap(find.text('Close'));
    await settle(t);
    expect(undone, isFalse);
    expect(find.text('Removed'), findsNothing);
  });
}
