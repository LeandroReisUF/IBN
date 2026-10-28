import 'package:flutter/foundation.dart';

/// Tipo de exame solicitado.
enum TipoExame {
  imagem('Imagem (RX, TC, RM, US)'),
  laboratorio('Laboratorial (Sangue, Urina, etc.)'),
  patologia('Patologia / Biópsia'),
  outro('Outro');

  final String rotulo;
  const TipoExame(this.rotulo);
}

/// Status do exame.
enum StatusExame {
  solicitado('Solicitado'),
  coletado('Coletado / Realizado'),
  emProcessamento('Em processamento'),
  pronto('Pronto / Resultado disponível'),
  cancelado('Cancelado');

  final String rotulo;
  const StatusExame(this.rotulo);
}

/// Exame solicitado/realizado.
class Exame {
  final String id;
  final String atendimentoId;
  final String pacienteId;
  final TipoExame tipo;
  final String nome;
  final String? descricao;
  final StatusExame status;
  final DateTime dataSolicitacao;
  final DateTime? dataRealizacao;
  final DateTime? dataResultado;
  final String profissionalSolicitanteId;
  final String? profissionalRealizadorId;
  final String? observacoes;
  final String? resultadoTexto;
  final List<String> arquivosResultado;

  const Exame({
    required this.id,
    required this.atendimentoId,
    required this.pacienteId,
    required this.tipo,
    required this.nome,
    this.descricao,
    this.status = StatusExame.solicitado,
    required this.dataSolicitacao,
    this.dataRealizacao,
    this.dataResultado,
    required this.profissionalSolicitanteId,
    this.profissionalRealizadorId,
    this.observacoes,
    this.resultadoTexto,
    this.arquivosResultado = const [],
  });

  Exame copiarCom({
    StatusExame? status,
    DateTime? dataRealizacao,
    DateTime? dataResultado,
    String? resultadoTexto,
    List<String>? arquivosResultado,
    String? observacoes,
  }) =>
      Exame(
        id: id,
        atendimentoId: atendimentoId,
        pacienteId: pacienteId,
        tipo: tipo,
        nome: nome,
        descricao: descricao,
        status: status ?? this.status,
        dataSolicitacao: dataSolicitacao,
        dataRealizacao: dataRealizacao ?? this.dataRealizacao,
        dataResultado: dataResultado ?? this.dataResultado,
/// Arquivo clínico anexado a exame, documento, etc.
class ArquivoClinico {
  final String id;
  final String entidadeId;
  final String entidadeTipo;
  final String nomeArquivo;
  final String mimeType;
  final String caminhoArquivo;
  final int tamanhoBytes;
  final DateTime enviadoEm;
  final String profissionalId;

  const ArquivoClinico({
    required this.id,
    required this.entidadeId,
    required this.entidadeTipo,
    required this.nomeArquivo,
    required this.mimeType,
    required this.caminhoArquivo,
    required this.tamanhoBytes,
    required this.enviadoEm,
    required this.profissionalId,
  });
}

/// Resultado laboratorial estruturado (para alertas automáticos).
class ResultadoLab {
  final String id;
  final String exameId;
  final String analito;
  final double valor;
  final String unidade;
  final double? refMin;
  final double? refMax;
  final String? observacao;

  const ResultadoLab({
    required this.id,
    required this.exameId,
    required this.analito,
    required this.valor,
    required this.unidade,
    this.refMin,
    this.refMax,
    this.observacao,
  });

  bool get foraDoPadrao {
    if (refMin != null && valor < refMin!) return true;
    if (refMax != null && valor > refMax!) return true;
    return false;
  }
}

/// Repository de Exames (em memória, PROVISÓRIO).
class ExamesRepository extends ChangeNotifier {
  final List<Exame> _exames = [];
  final List<ArquivoClinico> _arquivos = [];
  final List<ResultadoLab> _resultadosLab = [];
  int _contador = 0;

  ExamesRepository({bool comExemplos = false}) {
    if (comExemplos) _carregarExemplos();
  }

  String novoId() {
    _contador++;
    return 'exm${DateTime.now().microsecondsSinceEpoch}$_contador';
  }

  // ---------- Exames ----------

  List<Exame> examesDoPaciente(String pacienteId) =>
      _exames
          .where((e) => e.pacienteId == pacienteId)
          .toList()
        ..sort((a, b) => b.dataSolicitacao.compareTo(a.dataSolicitacao));

  List<Exame> examesDoAtendimento(String atendimentoId) =>
      _exames
          .where((e) => e.atendimentoId == atendimentoId)
          .toList()
        ..sort((a, b) => a.dataSolicitacao.compareTo(b.dataSolicitacao));

  Exame? examePorId(String id) {
    try {
      return _exames.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  String? solicitarExame(Exame e) {
    _exames.add(e);
    notifyListeners();
    return null;
  }

  String? atualizarExame(Exame e) {
    final idx = _exames.indexWhere((x) => x.id == e.id);
    if (idx == -1) return 'Exame não encontrado';
    _exames[idx] = e;
    notifyListeners();
    return null;
  }

  // ---------- Arquivos ----------

  List<ArquivoClinico> arquivosDoExame(String exameId) =>
      _arquivos.where((a) => a.entidadeId == exameId && a.entidadeTipo == 'exame').toList();

  String? adicionarArquivo(ArquivoClinico a) {
    _arquivos.add(a);
    notifyListeners();
    return null;
  }

  // ---------- Resultados Laboratoriais ----------

  List<ResultadoLab> resultadosDoExame(String exameId) =>
      _resultadosLab.where((r) => r.exameId == exameId).toList();

  String? adicionarResultadoLab(ResultadoLab r) {
    _resultadosLab.add(r);
    notifyListeners();
    return null;
  }

  List<ResultadoLab> alertasValoresCriticos(String pacienteId) {
    final examesPaciente = examesDoPaciente(pacienteId);
    final alertas = <ResultadoLab>[];
    for (final exame in examesPaciente) {
      final resultados = resultadosDoExame(exame.id);
      for (final r in resultados) {
        if (r.foraDoPadrao) alertas.add(r);
      }
    }
    return alertas;
  }

  void _carregarExemplos() {
    // Exemplos serão adicionados quando houver dados de teste
  }
}

final examesRepository = ExamesRepository();
        profissionalSolicitanteId: profissionalSolicitanteId,
        profissionalRealizadorId: profissionalRealizadorId,
        observacoes: observacoes ?? this.observacoes,
        resultadoTexto: resultadoTexto ?? this.resultadoTexto,
        arquivosResultado: arquivosResultado ?? this.arquivosResultado,
      );
}
