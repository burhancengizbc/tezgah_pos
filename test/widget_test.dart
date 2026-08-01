import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tezgah_pos/main.dart'; // main.dart'ın projenin içinde olduğundan emin ol

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Uygulamayı oluştur ve kareyi tetikle
    await tester.pumpWidget(const MyApp());

    // '0' metnini bul (findsOneWidget, flutter_test'ten gelir)
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // '+' ikonuna bas
    await tester.tap(find.byIcon(Icons.add));

    // UI güncellenmesi için pump
    await tester.pump();

    // '1' metninin oluştuğunu doğrula
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}

class MyApp {
  const MyApp();
}