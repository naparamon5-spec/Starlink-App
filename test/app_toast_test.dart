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

  testWidgets('success says Success, then leaves by itself', (t) async {
    await open(t);
    AppToast.success(ctx, 'Saved');
    await settle(t);
    expect(find.text('Success'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    await settle(t);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('success closes on a tap', (t) async {
    await open(t);
    AppToast.success(ctx, 'Saved');
    await settle(t);
    await t.tap(find.text('Saved'));
    await settle(t);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('failed says Failed and waits for OK', (t) async {
    await open(t);
    AppToast.error(ctx, 'No connection');
    await settle(t);
    expect(find.text('Failed'), findsOneWidget);
    await t.pump(const Duration(seconds: 30));
    expect(find.text('No connection'), findsOneWidget);
    await t.tap(find.text('OK'));
    await settle(t);
    expect(find.text('No connection'), findsNothing);
  });

  testWidgets('a new message replaces the current one', (t) async {
    await open(t);
    AppToast.success(ctx, 'One');
    await t.pump();
    AppToast.error(ctx, 'Two');
    await t.pump();
    expect(find.text('One'), findsNothing);
    expect(find.text('Two'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
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
}
