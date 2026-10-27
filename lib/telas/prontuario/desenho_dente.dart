import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/anatomia_dente.dart';
import '../../core/condicao_odonto.dart';
import '../../core/desenhos_dentes.dart';
import 'caixa_dente.dart' show EstiloMarca;

/// Marca ortodôntica desenhada sobre a coroa (Fase E).
class MarcaOrtoDesenho {
  final MarcaOrtodontia tipo;
  final Color cor;
  final EstiloMarca estilo;

  const MarcaOrtoDesenho({
    required this.tipo,
    required this.cor,
    this.estilo = EstiloMarca.solido,
  });

  @override
  bool operator ==(Object outro) =>
      outro is MarcaOrtoDesenho &&
      outro.tipo == tipo &&
      outro.cor == cor &&
      outro.estilo == estilo;

  @override
  int get hashCode => Object.hash(tipo, cor, estilo);
}

/// Tratamento marcado em uma raiz. [indice] é a posição da raiz, da esquerda
/// para a direita como aparece na tela (mesma ordem de `AnatomiaDente.raizes`).
class MarcaRaiz {
  final int indice;
  final Color cor;
  final String sigla;
  final EstiloMarca estilo;

  const MarcaRaiz({
    required this.indice,
    required this.cor,
    required this.sigla,
    this.estilo = EstiloMarca.solido,
  });

  @override
  bool operator ==(Object outro) =>
      outro is MarcaRaiz &&
      outro.indice == indice &&
      outro.cor == cor &&
      outro.sigla == sigla &&
      outro.estilo == estilo;

  @override
  int get hashCode => Object.hash(indice, cor, sigla, estilo);
}

/// Em qual faixa está a coordenada [x] dentro de [limites]?
/// Divide a raiz em [quantidade] faixas iguais, de 0 (esquerda) a quantidade - 1.
/// (Os SVGs trazem as raízes unidas em uma só silhueta; por isso a divisão.)
int faixaDaRaiz(double x, Rect limites, int quantidade) {
  if (quantidade <= 1) return 0;
  final largura = limites.width / quantidade;
  final i = ((x - limites.left) / largura).floor();
  if (i < 0) return 0;
  if (i >= quantidade) return quantidade - 1;
  return i;
}

/// Mostra o desenho 2D de um dente (coroa + raiz), vista vestibular.
/// Superiores: raiz para cima, alinhado embaixo. Inferiores: raiz para baixo,
/// alinhado em cima. Se o desenho não estiver carregado, ocupa o mesmo espaço vazio.
///
/// Marcações: [apagado] (dente ausente/extraído), [xVermelho] (extração
/// indicada), [corCoroa] (coroa/prótese), [marcasRaiz] e [selo] (sigla).
/// [fator] reduz o desenho (decíduos usam um dente menor).
class DenteDesenho extends StatelessWidget {
  final int numero;
  final bool apagado;
  final bool xVermelho;
  final Color? corCoroa;
  final String? selo;
  final Color corSelo;
  final List<MarcaOrtoDesenho> marcasOrto;
  final List<MarcaRaiz> marcasRaiz;
  final double fator;
  final VoidCallback? aoToqueCoroa;
  final void Function(int indiceRaiz)? aoToqueRaiz;

  static const double largura = 38;
  static const double altura = 64;

  /// Pixels por unidade do SVG. O mesmo valor vale para todos os dentes, assim
  /// o molar fica maior que o incisivo, como na boca.
  static const double escala = 0.38;

  const DenteDesenho({
    super.key,
    required this.numero,
    this.apagado = false,
    this.xVermelho = false,
    this.corCoroa,
    this.selo,
    this.corSelo = Colors.blueGrey,
    this.marcasOrto = const [],
    this.marcasRaiz = const [],
    this.fator = 1,
    this.aoToqueCoroa,
    this.aoToqueRaiz,
  });

  /// Converte um toque (em pixels do widget) para as coordenadas do SVG.
  Offset _paraDesenho(Offset local, DesenhoDente d) {
    final e = escala * fator;
    final w = d.tamanho.width * e;
    final h = d.tamanho.height * e;
    final dx = (largura * fator - w) / 2;
    final dy = AnatomiaDente.ehSuperior(numero) ? altura * fator - h : 0.0;
    var x = (local.dx - dx) / e;
    final y = (local.dy - dy) / e;
    if (AnatomiaDente.espelhado(numero)) x = d.tamanho.width - x;
    return Offset(x, y);
  }

  void _aoToque(Offset local, DesenhoDente? d) {
    if (d == null) {
      aoToqueCoroa?.call();
      return;
    }
    final p = _paraDesenho(local, d);
    if (d.coroaFundo.contains(p)) {
      aoToqueCoroa?.call();
      return;
    }
    if (d.limitesRaiz.inflate(2).contains(p)) {
      final n = AnatomiaDente.raizes(numero).length;
      final faixa = faixaDaRaiz(p.dx, d.limitesRaiz, n);
      // Nos dentes espelhados, a faixa 0 do desenho é a última na tela.
      final naTela = AnatomiaDente.espelhado(numero) ? n - 1 - faixa : faixa;
      aoToqueRaiz?.call(naTela);
    }
    // Toque fora do dente: ignora.
  }

  @override
  Widget build(BuildContext context) {
    final desenho = desenhosDentes.de(numero);
    final superior = AnatomiaDente.ehSuperior(numero);
    final larg = largura * fator;
    final alt = altura * fator;
    final interativo = aoToqueCoroa != null || aoToqueRaiz != null;

    final selagem = selo == null
        ? null
        : Positioned(
            right: 0,
            top: superior ? 0 : null,
            bottom: superior ? null : 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: corSelo,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.black38, width: 0.6),
              ),
              child: Text(
                selo!,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: ThemeData.estimateBrightnessForColor(corSelo) == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
            ),
          );

    return Tooltip(
      message: AnatomiaDente.nomeCompleto(numero),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: interativo ? (d) => _aoToque(d.localPosition, desenho) : null,
        child: SizedBox(
          width: larg,
          height: alt,
          child: Stack(
            children: [
              if (desenho != null)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DesenhoDentePainter(
                      desenho: desenho,
                      espelhar: AnatomiaDente.espelhado(numero),
                      alinharEmbaixo: superior,
                      opacidade: apagado ? 0.25 : 1,
                      corCoroa: corCoroa,
                      escala: escala * fator,
                      quantidadeRaizes: AnatomiaDente.raizes(numero).length,
                      marcasRaiz: marcasRaiz,
                      marcasOrto: marcasOrto,
                    ),
                  ),
                ),
              if (apagado)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Icon(Icons.close, color: Colors.black54),
                  ),
                ),
              if (xVermelho && !apagado)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Icon(Icons.close, color: Colors.red.shade700),
                  ),
                ),
              if (selagem != null) selagem,
            ],
          ),
        ),
      ),
    );
  }
}

class _DesenhoDentePainter extends CustomPainter {
  final DesenhoDente desenho;
  final bool espelhar;
  final bool alinharEmbaixo;
  final double opacidade;
  final Color? corCoroa;
  final double escala;
  final int quantidadeRaizes;
  final List<MarcaRaiz> marcasRaiz;
  final List<MarcaOrtoDesenho> marcasOrto;

  const _DesenhoDentePainter({
    required this.desenho,
    required this.espelhar,
    required this.alinharEmbaixo,
    required this.opacidade,
    required this.corCoroa,
    required this.escala,
    required this.quantidadeRaizes,
    required this.marcasRaiz,
    required this.marcasOrto,
  });

  static const _corCoroaPadrao = Color(0xFFFFFFFF);
  static const _corRaiz = Color(0xFFEFE6C8);
  static const _corLinha = Color(0xFF212121);

  /// Faixa (no desenho original) da raiz de índice [indice] na tela.
  int _faixaLocal(int indice) =>
      espelhar ? quantidadeRaizes - 1 - indice : indice;

  /// Desenha uma marca ortodôntica sobre a coroa.
  void _desenharMarcaOrto(Canvas canvas, MarcaOrtoDesenho marca) {
    final lc = desenho.limitesCoroa;
    final alfa = switch (marca.estilo) {
      EstiloMarca.solido => 1.0,
      EstiloMarca.emAndamento => 0.6,
      EstiloMarca.planejado => 0.35,
    };
    final tinta = Paint()
      ..style = PaintingStyle.fill
      ..color = marca.cor.withValues(alpha: opacidade * alfa);

    Paint tintaContorno(Color cor, double largura) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = largura
      ..color = cor.withValues(alpha: opacidade * alfa);

    switch (marca.tipo) {
      case MarcaOrtodontia.braqueteMetalico:
      case MarcaOrtodontia.braqueteEstetico:
        // Quadradinho no centro da coroa (face vestibular)
        final w = lc.width * 0.3;
        final h = lc.height * 0.15;
        final r = Rect.fromCenter(center: lc.center, width: w, height: h);
        canvas.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(1.5)), tinta);
        // Contorno metálico para braquete metálico
        if (marca.tipo == MarcaOrtodontia.braqueteMetalico) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(r, const Radius.circular(1.5)),
              tintaContorno(Colors.black54, 0.8));
        } else {
          // Braquete estético: contorno mais claro
          canvas.drawRRect(
              RRect.fromRectAndRadius(r, const Radius.circular(1.5)),
              tintaContorno(Colors.grey.shade400, 0.6));
        }
        break;

      case MarcaOrtodontia.banda:
        // Faixa fina ao redor da coroa
        final r = lc.inflate(1.5);
        canvas.drawRect(r, tintaContorno(marca.cor, 2.0));
        break;

      case MarcaOrtodontia.tubo:
        // Pequeno retângulo na borda incisal/oclusal (topo para sup, base para inf)
        final double y = alinharEmbaixo ? lc.top + 2 : lc.bottom - 2;
        final w = lc.width * 0.25;
        final h = 4.0;
        final r = Rect.fromCenter(
            center: Offset(lc.center.dx, y), width: w, height: h);
        canvas.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(1.0)), tinta);
        canvas.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(1.0)),
            tintaContorno(Colors.black54, 0.8));
        break;

      case MarcaOrtodontia.botao:
        // Pontinho na borda incisal/oclusal
        final double y = alinharEmbaixo ? lc.top + 4 : lc.bottom - 4;
        canvas.drawCircle(Offset(lc.center.dx, y), 2.5, tinta);
        break;

      case MarcaOrtodontia.contencaoFixa:
        // Linha fina na região cervical (face lingual - lado oposto ao vestibular)
        // Para dentes superiores (alinharEmbaixo=true), a face lingual é a parte de cima do desenho
        // Para dentes inferiores (alinharEmbaixo=false), a face lingual é a parte de baixo
        final double y = alinharEmbaixo ? lc.top + 6 : lc.bottom - 6;
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = marca.cor.withValues(alpha: opacidade * alfa);
        canvas.drawLine(Offset(lc.left + 2, y), Offset(lc.right - 2, y), p);
        break;

      case MarcaOrtodontia.miniImplante:
        // Parafuso entre coroa e raiz - desenhado na região da raiz
        // Vamos desenhar um pequeno X na região entre coroa e raiz
        final double y = alinharEmbaixo ? lc.top - 8 : lc.bottom + 8;
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = marca.cor.withValues(alpha: opacidade * alfa);
        final c = Offset(lc.center.dx, y);
        final s = 5.0;
        canvas.drawLine(Offset(c.dx - s, c.dy - s), Offset(c.dx + s, c.dy + s), p);
        canvas.drawLine(Offset(c.dx - s, c.dy + s), Offset(c.dx + s, c.dy - s), p);
        break;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final e = escala;
    final w = desenho.tamanho.width * e;
    final h = desenho.tamanho.height * e;
    final dx = (size.width - w) / 2;
    final dy = alinharEmbaixo ? size.height - h : 0.0;
    final lim = desenho.limitesRaiz;
    final n = quantidadeRaizes < 1 ? 1 : quantidadeRaizes;
    final larguraFaixa = lim.width / n;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(e);
    if (espelhar) {
      canvas.translate(desenho.tamanho.width, 0);
      canvas.scale(-1, 1);
    }

    Paint tinta(Color cor, [double alfa = 1]) => Paint()
      ..style = PaintingStyle.fill
      ..color = cor.withValues(alpha: opacidade * alfa);

    canvas.drawPath(desenho.raizFundo, tinta(_corRaiz));

    // Raízes marcadas: pinta só a faixa daquela raiz.
    for (final marca in marcasRaiz) {
      if (marca.indice < 0 || marca.indice >= n) continue;
      final faixa = _faixaLocal(marca.indice);
      final alfa = switch (marca.estilo) {
        EstiloMarca.solido => 0.85,
        EstiloMarca.emAndamento => 0.55,
        EstiloMarca.planejado => 0.35,
      };
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(
        lim.left + faixa * larguraFaixa,
        lim.top - 1,
        larguraFaixa,
        lim.height + 2,
      ));
      canvas.drawPath(desenho.raizFundo, tinta(marca.cor, alfa));
      canvas.restore();
    }

    canvas.drawPath(desenho.raizLinhas, tinta(_corLinha));
    canvas.drawPath(desenho.coroaFundo, tinta(corCoroa ?? _corCoroaPadrao));
    canvas.drawPath(desenho.coroaLinhas, tinta(_corLinha));

    // Marcas ortodônticas sobre a coroa (Fase E) — desenhadas no espaço SVG.
    for (final marca in marcasOrto) {
      _desenharMarcaOrto(canvas, marca);
    }

    canvas.restore();

    // Sigla perto do ápice de cada raiz marcada (em pixels da tela).
    for (final marca in marcasRaiz) {
      if (marca.indice < 0 || marca.indice >= n) continue;
      final faixa = _faixaLocal(marca.indice);
      final xLocal = lim.left + (faixa + 0.5) * larguraFaixa;
      final xDesenho = espelhar ? desenho.tamanho.width - xLocal : xLocal;
      final yApice = alinharEmbaixo ? lim.top : lim.bottom;
      final centro = Offset(
        dx + xDesenho * e,
        dy + yApice * e + (alinharEmbaixo ? 6 : -6),
      );
      final texto = TextPainter(
        text: TextSpan(
          text: marca.sigla,
          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: centro, width: texto.width + 4, height: texto.height + 2),
          const Radius.circular(3),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.85 * opacidade),
      );
      texto.paint(canvas, centro - Offset(texto.width / 2, texto.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _DesenhoDentePainter antigo) =>
      antigo.desenho != desenho ||
      antigo.espelhar != espelhar ||
      antigo.alinharEmbaixo != alinharEmbaixo ||
      antigo.opacidade != opacidade ||
      antigo.corCoroa != corCoroa ||
      antigo.escala != escala ||
      antigo.quantidadeRaizes != quantidadeRaizes ||
      !listEquals(antigo.marcasRaiz, marcasRaiz) ||
      !listEquals(antigo.marcasOrto, marcasOrto);
}