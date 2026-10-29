import 'package:ibn/features/odontograma/domain/odontograma.dart';

/// Regras sobre a numeração FDI: dentes permanentes (11–18, 21–28, 31–38, 41–48)
/// e decíduos (51–55, 61–65, 71–75, 81–85).
class AnatomiaDente {
  AnatomiaDente._();

  static const _nomesPermanentes = [
    'Incisivo central',
    'Incisivo lateral',
    'Canino',
    'Primeiro pré-molar',
    'Segundo pré-molar',
    'Primeiro molar',
    'Segundo molar',
    'Terceiro molar',
  ];

  static const _nomesDeciduos = [
    'Incisivo central decíduo',
    'Incisivo lateral decíduo',
    'Canino decíduo',
    'Primeiro molar decíduo',
    'Segundo molar decíduo',
  ];

  static bool ehPermanente(int numero) {
    final q = numero ~/ 10;
    final p = numero % 10;
    return q >= 1 && q <= 4 && p >= 1 && p <= 8;
  }

  static bool ehDeciduo(int numero) {
    final q = numero ~/ 10;
    final p = numero % 10;
    return q >= 5 && q <= 8 && p >= 1 && p <= 5;
  }

  static bool ehValido(int numero) => ehPermanente(numero) || ehDeciduo(numero);

  /// Quadrantes 1, 2, 5 e 6 são da arcada superior.
  static bool ehSuperior(int numero) {
    final q = numero ~/ 10;
    return q == 1 || q == 2 || q == 5 || q == 6;
  }

  /// 1 = incisivo central ... 8 = terceiro molar (decíduos: 1 a 5).
  static int posicao(int numero) => numero % 10;

  /// Lado direito do paciente = lado esquerdo do desenho (quadrantes 1, 4, 5 e 8).
  static bool ladoEsquerdoDoDesenho(int numero) {
    final q = numero ~/ 10;
    return q == 1 || q == 4 || q == 5 || q == 8;
  }

  /// Os dentes do lado esquerdo do paciente usam o desenho do lado direito,
  /// espelhado na horizontal.
  static bool espelhado(int numero) => !ladoEsquerdoDoDesenho(numero);

  /// Número do dente cujo desenho será usado (21→11, 36→46, 54→16, 83→43 ...).
  /// Decíduos reaproveitam os permanentes; os dois molares decíduos usam o 1º molar.
  static int numeroBase(int numero) {
    final q = numero ~/ 10;
    final p = numero % 10;
    if (ehDeciduo(numero)) {
      final posicaoBase = p >= 4 ? 6 : p;
      return (ehSuperior(numero) ? 10 : 40) + posicaoBase;
    }
    if (q == 2) return 10 + p;
    if (q == 3) return 40 + p;
    return numero;
  }

  /// Ex.: 16 → "16 — Primeiro molar superior direito".
  static String nomeCompleto(int numero) {
    if (!ehValido(numero)) return 'Dente $numero';
    final nomes = ehDeciduo(numero) ? _nomesDeciduos : _nomesPermanentes;
    final nome = nomes[posicao(numero) - 1];
    final arcada = ehSuperior(numero) ? 'superior' : 'inferior';
    final lado = ladoEsquerdoDoDesenho(numero) ? 'direito' : 'esquerdo';
    return '$numero — $nome $arcada $lado';
  }

  /// Raízes do dente, **da esquerda para a direita como aparecem na tela**.
  /// A mesial fica sempre do lado da linha média. Anatomia típica (esquemática):
  /// molares superiores 3 raízes, inferiores 2, 1º pré-molar superior 2, o resto 1.
  static List<RaizDente> raizes(int numero) {
    if (!ehValido(numero)) return const [];
    final pos = posicao(numero);
    final superior = ehSuperior(numero);
    final espelha = espelhado(numero);
    final molar = ehDeciduo(numero) ? pos >= 4 : pos >= 6;

    if (molar) {
      if (superior) {
        return espelha
            ? const [RaizDente.mesiovestibular, RaizDente.palatina, RaizDente.distovestibular]
            : const [RaizDente.distovestibular, RaizDente.palatina, RaizDente.mesiovestibular];
      }
      return espelha
          ? const [RaizDente.mesial, RaizDente.distal]
          : const [RaizDente.distal, RaizDente.mesial];
    }
    if (!ehDeciduo(numero) && superior && pos == 4) {
      return const [RaizDente.vestibular, RaizDente.palatina];
    }
    return const [RaizDente.unica];
  }
}