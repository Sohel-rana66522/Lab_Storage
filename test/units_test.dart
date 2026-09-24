import 'package:flutter_test/flutter_test.dart';
import 'package:lab_ledger/core/utils/formatters.dart';
import 'package:lab_ledger/core/utils/units.dart';

void main() {
  group('Units', () {
    test('same unit returns the value unchanged', () {
      expect(Units.convert(5, 'L', 'L'), 5);
    });

    test('converts within the volume dimension', () {
      expect(Units.convert(500, 'mL', 'L'), 0.5);
      expect(Units.convert(1.5, 'L', 'mL'), 1500);
    });

    test('converts within the mass dimension', () {
      expect(Units.convert(250, 'g', 'kg'), 0.25);
    });

    test('rejects cross-dimension conversion', () {
      expect(() => Units.convert(1, 'L', 'g'), throwsArgumentError);
    });

    test('isCompatible respects dimension', () {
      expect(Units.isCompatible('L', 'mL'), isTrue);
      expect(Units.isCompatible('L', 'kg'), isFalse);
    });
  });

  group('Formatters', () {
    test('formula converts digits to subscripts', () {
      expect(Fmt.formula('H2SO4'), 'H₂SO₄');
      expect(Fmt.formula('Ca(OH)2'), 'Ca(OH)₂');
    });

    test('qty trims to sensible precision', () {
      expect(Fmt.qty(12), '12.0');
      expect(Fmt.qty(8.5), '8.5');
    });
  });
}
