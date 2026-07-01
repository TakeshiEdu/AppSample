import 'package:flutter_test/flutter_test.dart';
import 'package:mr_remover/main.dart';

void main() {
  testWidgets('shows the extraction inputs', (tester) async {
    await tester.pumpWidget(const MrRemoverApp());
    await tester.pump();

    expect(find.text('MR REMOVER'), findsOneWidget);
    expect(find.text('原曲'), findsOneWidget);
    expect(find.text('インスト音源'), findsOneWidget);
    expect(find.text('ボーカルを抽出'), findsOneWidget);
  });
}
