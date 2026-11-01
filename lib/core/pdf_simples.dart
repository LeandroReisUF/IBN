import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Fontes embutidas (acentuação correta no PDF). Se os arquivos não existirem
/// nos assets, o PDF usa a fonte padrão (Helvetica), que também funciona.
const fonteRegular = 'lib/assets/fontes/Roboto-Regular.ttf';
const fonteNegrito = 'lib/assets/fontes/Roboto-Bold.ttf';

Future<pw.ThemeData> _tema() async {
  try {
    final regular = pw.Font.ttf(await rootBundle.load(fonteRegular));
    final negrito = pw.Font.ttf(await rootBundle.load(fonteNegrito));
    return pw.ThemeData.withFont(base: regular, bold: negrito);
  } catch (_) {
    return pw.ThemeData.base();
  }
}

/// PDF A4 com título, texto corrido (quebra em várias páginas) e rodapé opcional.
Future<Uint8List> gerarPdfSimples({
  required String titulo,
  required String corpo,
  String? rodape,
}) async {
  final doc = pw.Document(title: titulo);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      theme: await _tema(),
            // Uma linha por widget: o MultiPage só quebra a página entre widgets, e um
      // único Text muito longo não cabe em uma página.
      build: (_) => [
        pw.Text(titulo, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 16),
        for (final linha in corpo.split('\n'))
          linha.trim().isEmpty
              ? pw.SizedBox(height: 12)
              : pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(linha, style: const pw.TextStyle(fontSize: 12)),
                ),
      ],
      footer: rodape == null
          ? null
          : (_) => pw.Text(rodape, style: const pw.TextStyle(fontSize: 9)),
    ),
  );
  return doc.save();
}

/// Abre a pré-visualização/impressão de um PDF (Windows, Android e Web).
/// Serve tanto para PDFs gerados aqui quanto para PDFs anexados.
Future<bool> imprimirPdf(Uint8List bytes, String nome) =>
    Printing.layoutPdf(onLayout: (_) async => bytes, name: nome);