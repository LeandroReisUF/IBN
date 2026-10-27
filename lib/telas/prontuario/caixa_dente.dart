import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../../core/odontograma.dart';

enum EstiloCaixa { quadrada, redonda }

/// Como a marca de uma face é desenhada: sólido (existente/realizado),
/// tracejado e claro (planejado) ou meio claro (em andamento).
enum EstiloMarca { solido, planejado, emAndamento }

/// Cor (e listras opcionais) de uma face da caixa.
class MarcaFace {
  final Color cor;
  final Color? corListra;
  final EstiloMarca estilo;

  const MarcaFace({
    required this.cor,
    this.corListra,
    this.estilo = EstiloMarca.solido,
  });

  @override
  bool operator ==(Object outro) =>
      outro is MarcaFace &&
      outro.cor == cor &&
      outro.corListra == corListra &&
      outro.estilo == estilo;

  @override
  int get hashCode => Object.hash(cor, corListra, estilo);
}

/// Qual face está no ponto [p] de uma caixa de tamanho [tam]?
/// Devolve null se o ponto está fora da caixa.
///
/// A caixa tem um centro (face oclusal) e quatro setores separados pelas
/// diagonais. [topo], [base], [esquerda] e [direita] dizem qual face fica em
/// cada lado do desenho.
FaceDente? faceNoPonto(
  Offset p,
  Size tam,
  EstiloCaixa estilo, {
  required FaceDente topo,
  required FaceDente base,
  required FaceDente esquerda,
  required FaceDente direita,
}) {
  final x = p.dx / tam.width;
  final y = p.dy / tam.height;
  if (x < 0 || x > 1 || y < 0 || y > 1) return null;
  final dx = x - 0.5;
  final dy = y - 0.5;

  if (estilo == EstiloCaixa.redonda) {
    final r2 = dx * dx + dy * dy;
    if (r2 > 0.25) return null; // fora do círculo
    if (r2 < 0.05) return FaceDente.oclusal;
  } else {
    if (dx.abs() < 0.2 && dy.abs() < 0.2) return FaceDente.oclusal;
  }
  if (dx.abs() > dy.abs()) return dx < 0 ? esquerda : direita;
  return dy < 0 ? topo : base;
}

/// Caixa dividida (quadrada ou redonda) com as 5 faces do dente.
class CaixaDente extends StatelessWidget {
  final EstiloCaixa estilo;
  final FaceDente topo;
  final FaceDente base;
  final FaceDente esquerda;
  final FaceDente direita;
  final Map<FaceDente, MarcaFace> marcas;
  final bool ausente;
  final void Function(FaceDente face)? aoToqueFace;
  final double tamanho;

  const CaixaDente({
    super.key,
    this.estilo = EstiloCaixa.quadrada,
    required this.topo,
    required this.base,
    required this.esquerda,
    required this.direita,
    required this.marcas,
    this.ausente = false,
    this.aoToqueFace,
    this.tamanho = 38,
  });

  @override
  Widget build(BuildContext context) {
    final contorno = Theme.of(context).colorScheme.outline;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: aoToqueFace == null
          ? null
          : (detalhes) {
              final face = faceNoPonto(
                detalhes.localPosition,
                Size(tamanho, tamanho),
                estilo,
                topo: topo,
                base: base,
                esquerda: esquerda,
                direita: direita,
              );
              if (face != null) aoToqueFace!(face);
            },
      child: CustomPaint(
        size: Size(tamanho, tamanho),
        painter: _CaixaPainter(
          estilo: estilo,
          topo: topo,
          base: base,
          esquerda: esquerda,
          direita: direita,
          marcas: marcas,
          ausente: ausente,
          contorno: contorno,
        ),
      ),
    );
  }
}

class _CaixaPainter extends CustomPainter {
  final EstiloCaixa estilo;
  final FaceDente topo;
  final FaceDente base;
  final FaceDente esquerda;
  final FaceDente direita;
  final Map<FaceDente, MarcaFace> marcas;
  final bool ausente;
  final Color contorno;

  const _CaixaPainter({
    required this.estilo,
    required this.topo,
    required this.base,
    required this.esquerda,
    required this.direita,
    required this.marcas,
    required this.ausente,
    required this.contorno,
  });

  void _pintarFace(Canvas canvas, Path caminho, MarcaFace? marca, double s) {
    // Fundo branco por baixo, para o "claro" do planejado não ficar transparente.
    canvas.drawPath(
      caminho,
      Paint()
        ..style = PaintingStyle.fill
        ..color = ausente ? Colors.grey.shade300 : Colors.white,
    );
    if (ausente || marca == null) return;

    final alfa = switch (marca.estilo) {
      EstiloMarca.solido => 1.0,
      EstiloMarca.emAndamento => 0.6,
      EstiloMarca.planejado => 0.35,
    };
    canvas.drawPath(
      caminho,
      Paint()
        ..style = PaintingStyle.fill
        ..color = marca.cor.withValues(alpha: alfa),
    );

    final listra = marca.corListra;
    if (listra != null) {
      canvas.save();
      canvas.clipPath(caminho);
      final pincel = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = listra;
      for (var x = -s; x < s * 2; x += 5) {
        canvas.drawLine(Offset(x, s), Offset(x + s, 0), pincel);
      }
      canvas.restore();
    }

    if (marca.estilo == EstiloMarca.planejado) {
      canvas.drawPath(
        dashPath(caminho, dashArray: CircularIntervalList<double>(<double>[3, 2])),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = marca.cor,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final centro = Offset(s / 2, s / 2);
    final redonda = estilo == EstiloCaixa.redonda;
    final linha = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = contorno;

    final externo = redonda
        ? (Path()..addOval(Rect.fromCircle(center: centro, radius: s / 2)))
        : (Path()..addRect(Rect.fromLTWH(0, 0, s, s)));
    final miolo = redonda
        ? (Path()..addOval(Rect.fromCircle(center: centro, radius: s * math.sqrt(0.05))))
        : (Path()..addRect(Rect.fromLTWH(s * 0.3, s * 0.3, s * 0.4, s * 0.4)));

    Path triangulo(Offset a, Offset b) => Path()
      ..moveTo(centro.dx, centro.dy)
      ..lineTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..close();

    // Cada setor = triângulo com ponta no centro, sem o miolo, dentro da caixa.
    Path setor(Offset a, Offset b) => Path.combine(
          PathOperation.intersect,
          Path.combine(PathOperation.difference, triangulo(a, b), miolo),
          externo,
        );

    final setores = <FaceDente, Path>{
      topo: setor(const Offset(0, 0), Offset(s, 0)),
      direita: setor(Offset(s, 0), Offset(s, s)),
      base: setor(Offset(s, s), Offset(0, s)),
      esquerda: setor(Offset(0, s), const Offset(0, 0)),
      FaceDente.oclusal: miolo,
    };

    setores.forEach((face, caminho) => _pintarFace(canvas, caminho, marcas[face], s));
    for (final caminho in setores.values) {
      canvas.drawPath(caminho, linha);
    }

    if (ausente) {
      final x = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.black54;
      canvas.drawLine(Offset(s * 0.15, s * 0.15), Offset(s * 0.85, s * 0.85), x);
      canvas.drawLine(Offset(s * 0.85, s * 0.15), Offset(s * 0.15, s * 0.85), x);
    }
  }

  @override
  bool shouldRepaint(covariant _CaixaPainter antigo) =>
      antigo.estilo != estilo ||
      antigo.ausente != ausente ||
      antigo.contorno != contorno ||
      antigo.topo != topo ||
      antigo.base != base ||
      antigo.esquerda != esquerda ||
      antigo.direita != direita ||
      !mapEquals(antigo.marcas, marcas);
}