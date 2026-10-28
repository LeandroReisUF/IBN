import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/core/anatomia_dente.dart';
import 'package:ibn/core/odontograma.dart';

void main() {
  group('AnatomiaDente - numeração', () {
    test('valida os dentes permanentes e os decíduos', () {
      expect(AnatomiaDente.ehValido(18), isTrue);
      expect(AnatomiaDente.ehValido(41), isTrue);
      expect(AnatomiaDente.ehValido(19), isFalse);
      expect(AnatomiaDente.ehValido(49), isFalse);
      expect(AnatomiaDente.ehValido(10), isFalse);
      expect(AnatomiaDente.ehValido(51), isTrue); // decíduo
      expect(AnatomiaDente.ehValido(85), isTrue);
      expect(AnatomiaDente.ehValido(56), isFalse);
      expect(AnatomiaDente.ehValido(86), isFalse);
      expect(AnatomiaDente.ehValido(91), isFalse);
    });

    test('distingue decíduos de permanentes', () {
      expect(AnatomiaDente.ehDeciduo(55), isTrue);
      expect(AnatomiaDente.ehDeciduo(71), isTrue);
      expect(AnatomiaDente.ehDeciduo(16), isFalse);
      expect(AnatomiaDente.ehPermanente(16), isTrue);
      expect(AnatomiaDente.ehPermanente(55), isFalse);
    });

    test('quadrantes 2, 3, 6 e 7 usam o desenho do lado direito, espelhado', () {
      expect(AnatomiaDente.numeroBase(21), 11);
      expect(AnatomiaDente.numeroBase(28), 18);
      expect(AnatomiaDente.numeroBase(36), 46);
      expect(AnatomiaDente.numeroBase(11), 11);
      expect(AnatomiaDente.numeroBase(48), 48);
      expect(AnatomiaDente.espelhado(21), isTrue);
      expect(AnatomiaDente.espelhado(33), isTrue);
      expect(AnatomiaDente.espelhado(62), isTrue);
      expect(AnatomiaDente.espelhado(74), isTrue);
      expect(AnatomiaDente.espelhado(11), isFalse);
      expect(AnatomiaDente.espelhado(44), isFalse);
      expect(AnatomiaDente.espelhado(53), isFalse);
      expect(AnatomiaDente.espelhado(81), isFalse);
    });

    test('decíduos reaproveitam o desenho de um permanente', () {
      expect(AnatomiaDente.numeroBase(51), 11);
      expect(AnatomiaDente.numeroBase(62), 12);
      expect(AnatomiaDente.numeroBase(53), 13);
      expect(AnatomiaDente.numeroBase(54), 16); // 1º molar decíduo
      expect(AnatomiaDente.numeroBase(65), 16); // 2º molar decíduo
      expect(AnatomiaDente.numeroBase(81), 41);
      expect(AnatomiaDente.numeroBase(74), 46);
      expect(AnatomiaDente.numeroBase(75), 46);
    });

    test('arcada superior são os quadrantes 1, 2, 5 e 6', () {
      expect(AnatomiaDente.ehSuperior(16), isTrue);
      expect(AnatomiaDente.ehSuperior(26), isTrue);
      expect(AnatomiaDente.ehSuperior(54), isTrue);
      expect(AnatomiaDente.ehSuperior(63), isTrue);
      expect(AnatomiaDente.ehSuperior(36), isFalse);
      expect(AnatomiaDente.ehSuperior(46), isFalse);
      expect(AnatomiaDente.ehSuperior(72), isFalse);
      expect(AnatomiaDente.ehSuperior(85), isFalse);
    });

    test('nome completo do dente', () {
      expect(AnatomiaDente.nomeCompleto(16), '16 — Primeiro molar superior direito');
      expect(AnatomiaDente.nomeCompleto(38), '38 — Terceiro molar inferior esquerdo');
      expect(AnatomiaDente.nomeCompleto(23), '23 — Canino superior esquerdo');
      expect(AnatomiaDente.nomeCompleto(54), '54 — Primeiro molar decíduo superior direito');
      expect(AnatomiaDente.nomeCompleto(71), '71 — Incisivo central decíduo inferior esquerdo');
      expect(AnatomiaDente.nomeCompleto(99), 'Dente 99');
    });
  });

  group('AnatomiaDente - raízes', () {
    test('quantidade de raízes por tipo de dente', () {
      expect(AnatomiaDente.raizes(11), [RaizDente.unica]);
      expect(AnatomiaDente.raizes(33), [RaizDente.unica]); // canino
      expect(AnatomiaDente.raizes(15), [RaizDente.unica]); // 2º pré-molar sup.
      expect(AnatomiaDente.raizes(44), [RaizDente.unica]); // pré-molar inf.
      expect(AnatomiaDente.raizes(14).length, 2); // 1º pré-molar superior
      expect(AnatomiaDente.raizes(26).length, 3); // molar superior
      expect(AnatomiaDente.raizes(18).length, 3); // siso superior segue o molar
      expect(AnatomiaDente.raizes(36).length, 2); // molar inferior
      expect(AnatomiaDente.raizes(48).length, 2);
      expect(AnatomiaDente.raizes(99), isEmpty);
    });

    test('a raiz mesial fica sempre do lado da linha média (na tela)', () {
      // 16 e 46 ficam à esquerda do desenho: a linha média está à direita.
      expect(AnatomiaDente.raizes(16).last, RaizDente.mesiovestibular);
      expect(AnatomiaDente.raizes(46).last, RaizDente.mesial);
      // 26 e 36 ficam à direita do desenho: a linha média está à esquerda.
      expect(AnatomiaDente.raizes(26).first, RaizDente.mesiovestibular);
      expect(AnatomiaDente.raizes(36).first, RaizDente.mesial);
    });

    test('molar superior tem a raiz palatina no meio', () {
      expect(AnatomiaDente.raizes(16)[1], RaizDente.palatina);
      expect(AnatomiaDente.raizes(27)[1], RaizDente.palatina);
    });

    test('molares decíduos: 3 raízes em cima e 2 embaixo', () {
      expect(AnatomiaDente.raizes(54).length, 3);
      expect(AnatomiaDente.raizes(65).length, 3);
      expect(AnatomiaDente.raizes(74).length, 2);
      expect(AnatomiaDente.raizes(85).length, 2);
      expect(AnatomiaDente.raizes(53), [RaizDente.unica]);
    });
  });
}