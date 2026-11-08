import 'dart:typed_data';

/// Exames (RF04.3). Modelos imutáveis.
/// Arquivos clínicos são só de inclusão: substituir = novo arquivo que
/// retifica o anterior, com justificativa (RN05).

enum TipoExame {
  imagem('Imagem (radiografia, tomografia)'),
  laboratorial('Laboratorial'),
  patologia('Patologia / biópsia'),
  outro('Outro');

  final String rotulo;
  const TipoExame(this.rotulo);
}

enum StatusExame {
  solicitado('Solicitado'),
  realizado('Realizado'),
  resultadoDisponivel('Resultado disponível'),
  cancelado('Cancelado');

  final String rotulo;
  const StatusExame(this.rotulo);

  /// Para onde este status pode ir (só para frente, ou cancelar).
  List<StatusExame> get proximos => switch (this) {
        StatusExame.solicitado => const [StatusExame.realizado, StatusExame.cancelado],
        StatusExame.realizado => const [StatusExame.resultadoDisponivel, StatusExame.cancelado],
        StatusExame.resultadoDisponivel || StatusExame.cancelado => const [],
      };
}

/// Exame solicitado dentro de um atendimento.
class Exame {
  final String id;
  final String pacienteId;
  final String atendimentoId;
  final String profissionalId; // quem solicitou
  final TipoExame tipo;
  final String nome;
  final String? descricao;
  final StatusExame status;
  final DateTime solicitadoEm;
  final DateTime atualizadoEm;

  const Exame({
    required this.id,
    required this.pacienteId,
    required this.atendimentoId,
    required this.profissionalId,
    required this.tipo,
    required this.nome,
    this.descricao,
    this.status = StatusExame.solicitado,
    required this.solicitadoEm,
    required this.atualizadoEm,
  });

  Exame copiarCom({StatusExame? status, DateTime? atualizadoEm}) => Exame(
        id: id,
        pacienteId: pacienteId,
        atendimentoId: atendimentoId,
        profissionalId: profissionalId,
        tipo: tipo,
        nome: nome,
        descricao: descricao,
        status: status ?? this.status,
        solicitadoEm: solicitadoEm,
        atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      );
}

/// Extensões aceitas e o tipo MIME de cada uma.
const tiposArquivoPermitidos = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'pdf': 'application/pdf',
};

const limiteArquivoBytes = 10 * 1024 * 1024;

/// MIME do arquivo pelo nome, ou null se o formato não é permitido.
String? mimeDoArquivo(String nome) {
  final i = nome.lastIndexOf('.');
  if (i < 0 || i == nome.length - 1) return null;
  return tiposArquivoPermitidos[nome.substring(i + 1).toLowerCase()];
}

/// Radiografia, foto ou laudo anexado a um exame. Só inclusão.
class ArquivoClinico {
  final String id;
  final String exameId;
  final String pacienteId;
  final String nomeArquivo;
  final String mimeType;
  final Uint8List bytes;
  final DateTime enviadoEm;
  final String profissionalId;
  final String? retificaId;
  final String? justificativa;

  const ArquivoClinico({
    required this.id,
    required this.exameId,
    required this.pacienteId,
    required this.nomeArquivo,
    required this.mimeType,
    required this.bytes,
    required this.enviadoEm,
    required this.profissionalId,
    this.retificaId,
    this.justificativa,
  });

  int get tamanhoBytes => bytes.length;
  bool get ehImagem => mimeType.startsWith('image/');
  bool get ehPdf => mimeType == 'application/pdf';
}

/// Modelo de guia de solicitação (preenche tipo e nome).
class GuiaModelo {
  final String nome;
  final TipoExame tipo;
  final String descricao;
  const GuiaModelo(this.nome, this.tipo, this.descricao);
}

/// PROVISÓRIO: validar a lista com os dentistas da clínica.
const guiasExame = [
  GuiaModelo('Radiografia periapical', TipoExame.imagem, 'Região a especificar.'),
  GuiaModelo('Radiografia panorâmica', TipoExame.imagem, 'Arcadas superior e inferior.'),
  GuiaModelo('Tomografia computadorizada', TipoExame.imagem, 'Região a especificar.'),
  GuiaModelo('Hemograma completo (pré-operatório)', TipoExame.laboratorial, ''),
  GuiaModelo('Hemograma completo', TipoExame.laboratorial, ''),
  GuiaModelo('Coagulograma (pré-operatório)', TipoExame.laboratorial, ''),
  GuiaModelo('Glicemia em jejum (pré-operatório)', TipoExame.laboratorial, ''),
  GuiaModelo('TSH e T4 livre', TipoExame.laboratorial, ''),
  GuiaModelo('Vitamina D (25-OH)', TipoExame.laboratorial, ''),
];
/// Resultado laboratorial estruturado (usado pela Biomedicina, Passo 6).
class ResultadoLab {
  final String analito;
  final double valor;
  final String unidade;
  final double? refMin;
  final double? refMax;

  const ResultadoLab({
    required this.analito,
    required this.valor,
    required this.unidade,
    this.refMin,
    this.refMax,
  });

  bool get foraDoPadrao =>
      (refMin != null && valor < refMin!) || (refMax != null && valor > refMax!);
}