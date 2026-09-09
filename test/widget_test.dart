import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pcb_boxing_system/main.dart';

void main() {
  testWidgets('PCB boxing screen smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PCBBoxingApp());

    expect(find.text('Ilsan Packing System'), findsOneWidget);
    expect(find.text('Box Id'), findsAtLeastNWidgets(1));
    expect(find.text('BarCode'), findsAtLeastNWidgets(1));
    expect(find.text('Send'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNothing);
  });
}
