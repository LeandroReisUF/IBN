import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Imagem escolhida pelo usuário, já lida em memória.
class ArquivoSelecionado {
  final String nome;
  final Uint8List bytes;
  const ArquivoSelecionado(this.nome, this.bytes);
}

/// Resultado de [escolherImagem]: ou o [arquivo], ou o [erro].
class ResultadoSelecao {
  final ArquivoSelecionado? arquivo;
  final String? erro;
  const ResultadoSelecao.ok(ArquivoSelecionado this.arquivo) : erro = null;
  const ResultadoSelecao.falha(String this.erro) : arquivo = null;
}

const limiteImagemBytes = 10 * 1024 * 1024;

/// Abre o seletor de imagens. Devolve null se o usuário cancelou.
/// Funciona em Windows, Android e Web (só bytes em memória).
Future<ResultadoSelecao?> escolherImagem({int limiteBytes = limiteImagemBytes}) async {
  final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
  if (r == null || r.files.isEmpty) return null;
  final arquivo = r.files.first;
  final bytes = arquivo.bytes;
  if (bytes == null) return const ResultadoSelecao.falha('Não foi possível ler o arquivo.');
  if (bytes.length > limiteBytes) {
    return const ResultadoSelecao.falha('A imagem tem mais de 10 MB.');
  }
  return ResultadoSelecao.ok(ArquivoSelecionado(arquivo.name, bytes));
}