import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pcb_boxing_system/main.dart';
import 'package:pcb_boxing_system/services/api_service.dart';

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

  test('normalizes both SMD QR separator formats to the same value', () {
    const qrWithN =
        'I20240110\u20190052\u201900608\u00f1MAIN\u00f1EBR80757421\u00f11\u00f1';
    const qrWithSemicolons =
        'I20240110-0052-00608;MAIN;EBR80757421;1;';

    final first = ApiService.parseBarcode(qrWithN);
    final second = ApiService.parseBarcode(qrWithSemicolons);

    expect(first?.isSmdQr, isTrue);
    expect(first?.partNumber, 'EBR80757421');
    expect(first?.value, qrWithSemicolons);
    expect(first?.comparisonKey, second?.comparisonKey);
  });

  test('keeps production barcode parsing independent from SMD QR parsing', () {
    const productionBarcode = 'ebr80757421922407030048';

    expect(ApiService.extractPartNumber(productionBarcode), 'ebr80757421');
    expect(
      ApiService.barcodeComparisonKey(productionBarcode),
      'EBR80757421922407030048',
    );
    expect(
      ApiService.validateBarcode(productionBarcode, productionType: 'MAIN_PCB'),
      isNull,
    );
  });

  test('does not accept an SMD QR in MAIN PCB', () {
    const smdQr = 'I20240110-0052-00608;MAIN;EBR80757421;1;';

    expect(
      ApiService.validateBarcode(smdQr, productionType: 'MAIN_PCB'),
      'MAIN PCB solo acepta Barcode de produccion',
    );
  });
}
