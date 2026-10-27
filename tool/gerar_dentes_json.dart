// Ferramenta de desenvolvimento: junta os SVGs do odontograma em UM arquivo JSON.
//
// Uso (na raiz do projeto):
//   dart run tool/gerar_dentes_json.dart
//   dart run tool/gerar_dentes_json.dart <pasta-dos-svgs> <arquivo-de-saida>
//
// Lê, para os dentes 11–18 e 41–48 (pacote do hemiarco DIREITO), os arquivos
//   NN_vestibular_coroa.svg  e  NN_vestibular_raiz.svg
// e grava os caminhos (atributo "d" dos <path>) em dentes_vestibular.json.
// Os dentes 21–28 e 31–38 são desenhados espelhando 11–18 e 41–48 no app.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final pasta = Directory(args.isNotEmpty ? args[0] : 'lib/assets/odontograma');
  if (!pasta.existsSync()) {
    stderr.writeln('Pasta não encontrada: ${pasta.path}');
    stderr.writeln('Rode este comando na raiz do projeto ou informe a pasta dos SVGs.');
    exit(1);
  }
  final saida = File(
    args.length > 1 ? args[1] : '${pasta.path}/dentes_vestibular.json',
  );

  // Procura os arquivos em qualquer subpasta pelo NOME do arquivo.
  final padrao = RegExp(r'^((?:1|4)[1-8])_vestibular_(coroa|raiz)\.svg$');
  final arquivos = <String, Map<String, File>>{};
  for (final item in pasta.listSync(recursive: true)) {
    if (item is! File) continue;
    final nome = item.path.split(RegExp(r'[\\/]')).last;
    final m = padrao.firstMatch(nome);
    if (m == null) continue;
    arquivos.putIfAbsent(m.group(1)!, () => {})[m.group(2)!] = item;
  }

  final dentes = <String, Object>{};
  final problemas = <String>[];
  final esperados = [
    for (var i = 8; i >= 1; i--) '1$i',
    for (var i = 8; i >= 1; i--) '4$i',
  ];

  for (final numero in esperados) {
    final partes = arquivos[numero];
    if (partes == null || partes['coroa'] == null || partes['raiz'] == null) {
      problemas.add('Dente $numero: faltam arquivos vestibular (coroa/raiz).');
      continue;
    }
    final coroa = _ler(partes['coroa']!);
    final raiz = _ler(partes['raiz']!);
    if (coroa == null || raiz == null) {
      problemas.add('Dente $numero: não consegui ler os caminhos dos SVGs.');
      continue;
    }
    dentes[numero] = {
      'w': coroa.largura,
      'h': coroa.altura,
      'coroa': {'fundo': coroa.fundo, 'linhas': coroa.linhas},
      'raiz': {'fundo': raiz.fundo, 'linhas': raiz.linhas},
    };
  }

  if (problemas.isNotEmpty) {
    stderr.writeln('ATENÇÃO:');
    for (final p in problemas) {
      stderr.writeln('  - $p');
    }
  }
  if (dentes.isEmpty) {
    stderr.writeln('Nenhum dente foi lido. Confira a pasta: ${pasta.path}');
    exit(1);
  }

  saida.writeAsStringSync(jsonEncode({'formato': 1, 'dentes': dentes}));
  final kb = (saida.lengthSync() / 1024).toStringAsFixed(0);
  stdout.writeln('Pronto: ${dentes.length} de ${esperados.length} dentes gravados em ${saida.path} ($kb KB).');
}

class _Parte {
  final double largura;
  final double altura;
  final String fundo;
  final String linhas;
  _Parte(this.largura, this.altura, this.fundo, this.linhas);
}

_Parte? _ler(File arquivo) {
  final svg = arquivo.readAsStringSync();
  final vb = RegExp(r'viewBox="\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*"').firstMatch(svg);
  if (vb == null) return null;

  String? fundo;
  String? linhas;
  for (final tag in RegExp(r'<path\b[^>]*>', dotAll: true).allMatches(svg)) {
    final texto = tag.group(0)!;
    final id = RegExp(r'\bid="([^"]+)"').firstMatch(texto)?.group(1);
    final d = RegExp(r'\sd="([^"]+)"').firstMatch(texto)?.group(1);
    if (id == null || d == null) continue;
    if (id.endsWith('-fundo')) fundo = d;
    if (id.endsWith('-linhas')) linhas = d;
  }
  if (fundo == null || linhas == null) return null;
  return _Parte(double.parse(vb.group(1)!), double.parse(vb.group(2)!), fundo, linhas);
}