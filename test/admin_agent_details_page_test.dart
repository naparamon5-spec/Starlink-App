import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starlink_app/features/admin/sections/agent/admin_agent_details_page.dart';

void main() {
  testWidgets('AdminAgentDetailsPage subscription buttons styling', (WidgetTester tester) async {
    // Assuming the page is wrapped in a MaterialApp/Scaffold for navigation context
    await tester.pumpWidget(
      const MaterialApp(
        home: AdminAgentDetailsPage(
          agentId: 'test-id',
          agentCode: 'test-code',
          agentName: 'Test Agent',
        ),
      ),
    );

    // Initial state (Edit button visible)
    expect(find.text('Edit'), findsOneWidget);
    
    // Tap 'Edit'
    await tester.tap(find.text('Edit'));
    await tester.pump();

    // Verify 'Add Subscription' exists and has expected style (foreground color: black)
    final addSubButton = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(addSubButton.style?.foregroundColor?.resolve({})?.value, const Color(0xFF000000).value);

    // Verify 'Cancel' and 'Save' buttons exist and have expected colors
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    
    final saveButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton).last);
    expect(saveButton.style?.backgroundColor?.resolve({})?.value, const Color(0xFF000000).value);
  });
}
