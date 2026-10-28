import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/telas/prontuario/desenho_dente.dart';

void main() {
  group('faixaDaRaiz', () {
    // Raiz entre x = 10 e x = 70 (largura 60).
    const limites = Rect.fromLTRB(10, 0, 70, 100);

    test('com uma raiz, é sempre a faixa 0', () {
      expect(faixaDaRaiz(12, limites, 1), 0);
      expect(faixaDaRaiz(69, limites, 1), 0);
    });

    test('com duas raízes, divide ao meio', () {
      expect(faixaDaRaiz(20, limites, 2), 0);
      expect(faixaDaRaiz(60, limites, 2), 1);
    });

    test('com três raízes, divide em terços', () {
      expect(faixaDaRaiz(15, limites, 3), 0);
      expect(faixaDaRaiz(40, limites, 3), 1);
      expect(faixaDaRaiz(65, limites, 3), 2);
    });

    test('fora dos limites, usa a faixa mais próxima', () {
      expect(faixaDaRaiz(-5, limites, 3), 0);
      expect(faixaDaRaiz(200, limites, 3), 2);
    });
  });
}