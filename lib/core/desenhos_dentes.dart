import 'dart:convert';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';
import 'anatomia_dente.dart';

/// Arquivo gerado por `dart run tool/gerar_dentes_json.dart`.
/// Precisa estar declarado em `flutter: assets:` no pubspec.yaml.
const caminhoDesenhosDentes = 'lib/assets/odontograma/dentes_vestibular.json';

/// Desenho vetorial de um dente (vista vestibular), em unidades do SVG original.
/// "fundo" é a silhueta (para pintar e para toque); "linhas" é o contorno.
class DesenhoDente {
  final Size tamanho;
  final Path coroaFundo;
  final Path coroaLinhas;
  final Path raizFundo;
  final Path raizLinhas;

  /// Retângulo que envolve a coroa (para posicionar marcas ortodônticas).
  final Rect limitesCoroa;

  /// Retângulo que envolve a raiz (para dividir em faixas as raízes múltiplas).
  final Rect limitesRaiz;

  const DesenhoDente({
    required this.tamanho,
    required this.coroaFundo,
    required this.coroaLinhas,
    required this.raizFundo,
    required this.raizLinhas,
    required this.limitesCoroa,
    required this.limitesRaiz,
  });
}

/// Carrega os desenhos uma única vez e os guarda na memória.
class DesenhosDentes {
  final Map<int, DesenhoDente> _porNumero = {};
  Future<void>? _carregando;

  bool get carregado => _porNumero.isNotEmpty;

  /// Pode ser chamado várias vezes: lê o arquivo só na primeira.
  Future<void> carregar() => _carregando ??= _ler();

  Future<void> _ler() async {
    final texto = await rootBundle.loadString(caminhoDesenhosDentes);
    final json = jsonDecode(texto) as Map<String, dynamic>;
    final dentes = json['dentes'] as Map<String, dynamic>;

    Path caminho(Map<String, dynamic> parte, String nome) =>
        parseSvgPathData(parte[nome] as String)..fillType = PathFillType.evenOdd;

    dentes.forEach((chave, valor) {
      final v = valor as Map<String, dynamic>;
      final coroa = v['coroa'] as Map<String, dynamic>;
      final raiz = v['raiz'] as Map<String, dynamic>;
      final coroaFundo = caminho(coroa, 'fundo');
      final raizFundo = caminho(raiz, 'fundo');
      _porNumero[int.parse(chave)] = DesenhoDente(
        tamanho: Size((v['w'] as num).toDouble(), (v['h'] as num).toDouble()),
        coroaFundo: coroaFundo,
        coroaLinhas: caminho(coroa, 'linhas'),
        raizFundo: raizFundo,
        raizLinhas: caminho(raiz, 'linhas'),
        limitesCoroa: coroaFundo.getBounds(),
        limitesRaiz: raizFundo.getBounds(),
      );
    });
  }

  /// Desenho do dente [numero] (os dentes 2x e 3x usam o de 1x e 4x espelhado).
  DesenhoDente? de(int numero) => _porNumero[AnatomiaDente.numeroBase(numero)];
}

final desenhosDentes = DesenhosDentes();