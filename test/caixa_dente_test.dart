import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/odontograma.dart';
import '../lib/telas/prontuario/caixa_dente.dart';

// Caixa de 100 x 100. Lados: topo = vestibular, base = lingual,
// esquerda = distal, direita = mesial (como um dente do quadrante 1).
FaceDente? toque(double x, double y, EstiloCaixa estilo) => faceNoPonto(
      Offset(x, y),
      const Size(100, 100),
      estilo,
      topo: FaceDente.vestibular,
      base: FaceDente.lingual,
      esquerda: FaceDente.distal,
      direita: FaceDente.mesial,
    );

void main() {
  for (final estilo in EstiloCaixa.values) {
    group('faceNoPonto ($estilo)', () {
      test('o centro é a face oclusal', () {
        expect(toque(50, 50, estilo), FaceDente.oclusal);
      });

      test('cada lado devolve a face correta', () {
        expect(toque(50, 12, estilo), FaceDente.vestibular);
        expect(toque(50, 88, estilo), FaceDente.lingual);
        expect(toque(12, 50, estilo), FaceDente.distal);
        expect(toque(88, 50, estilo), FaceDente.mesial);
      });

      test('os cantos seguem as diagonais', () {
        // Perto do canto superior esquerdo: mais perto do topo que da esquerda.
        expect(toque(30, 20, estilo), FaceDente.vestibular);
        expect(toque(20, 30, estilo), FaceDente.distal);
        // Canto inferior direito.
        expect(toque(70, 80, estilo), FaceDente.lingual);
        expect(toque(80, 70, estilo), FaceDente.mesial);
      });

      test('fora da caixa não devolve face', () {
        expect(toque(-1, 50, estilo), isNull);
        expect(toque(50, 101, estilo), isNull);
      });
    });
  }

  test('na caixa redonda, o canto fica fora do círculo', () {
    expect(toque(3, 3, EstiloCaixa.redonda), isNull);
    expect(toque(3, 3, EstiloCaixa.quadrada), isNotNull);
  });
}