import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/shared/ui/section_card.dart';

void main() {
  testWidgets('SectionCard renders child content', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SectionCard(child: Text('Plugin workspace'))),
      ),
    );

    expect(find.byType(Card), findsOneWidget);
    expect(find.text('Plugin workspace'), findsOneWidget);
  });
}
