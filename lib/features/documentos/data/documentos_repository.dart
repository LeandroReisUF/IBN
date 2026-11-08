import 'package:flutter/foundation.dart';
import 'package:ibn/features/documentos/domain/documentos.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';

/// Modelos e documentos clínicos em memória (PROVISÓRIO).
///
/// Regras (RN05):
/// - documento novo nasce como rascunho e só dentro de um atendimento em aberto;
/// - rascunho pode ser editado ou descartado; assinado, nunca mais muda;
/// - não assina com campos "NÃO PREENCHIDO";
/// - correção de documento assinado = novo documento (rascunho) que o retifica,
///   com justificativa, do mesmo autor e no mesmo atendimento;
/// - modelos são versionados: editar cria uma nova versão.
///
/// ATENÇÃO: no servidor estas mesmas regras precisam ser repetidas.
class DocumentosRepository extends ChangeNotifier {
  DocumentosRepository({
    required ProntuarioRepository prontuario,
    List<ModeloDocumento> modelosIniciais = modelosPadrao,
    }) : _prontuario = prontuario {
    _modelos.addAll(modelosIniciais);
    _prontuario.registrarBloqueioEncerramento(_rascunhosPendentes);
  }
  final ProntuarioRepository _prontuario;
  final List<ModeloDocumento> _modelos = []; // todas as versões
  final List<DocumentoClinico> _documentos = [];
  int _contador = 0;

  String novoId() {
    _contador++;
    return 'doc${DateTime.now().microsecondsSinceEpoch}$_contador';
  }

  /// Selo provisório de integridade (não é assinatura digital).
  static String _selo(String autor, DateTime quando, String texto) {
    final h = Object.hashAll('$autor|${quando.toIso8601String()}|$texto'.codeUnits);
    return h.toUnsigned(32).toRadixString(16).padLeft(8, '0');
  }
  /// Impede encerrar o atendimento com rascunho de documento pendente.
  String? _rascunhosPendentes(String atendimentoId) {
    final n = _documentos.where((d) => d.atendimentoId == atendimentoId && !d.assinado).length;
    return n == 0
        ? null
        : 'Assine ou descarte os rascunhos de documento antes de encerrar ($n pendente(s)).';
  }
  // ---------- modelos ----------

  /// Última versão de cada modelo, na ordem em que foram criados.
  List<ModeloDocumento> get modelos {
    final ultimos = <String, ModeloDocumento>{};
    for (final m in _modelos) {
      ultimos[m.id] = m;
    }
    return ultimos.values.toList();
  }

  ModeloDocumento? modeloPorId(String id) {
    for (final m in modelos) {
      if (m.id == id) return m;
    }
    return null;
  }

  List<ModeloDocumento> historicoModelo(String id) =>
      _modelos.where((m) => m.id == id).toList().reversed.toList();

  /// Salva uma nova versão do modelo (ou cria o modelo, se o id for novo).
  String? salvarModelo(ModeloDocumento m) {
    if (m.nome.trim().isEmpty) return 'Informe o nome do modelo.';
    if (m.corpo.trim().isEmpty) return 'Escreva o texto do modelo.';
    final atual = modeloPorId(m.id);
    _modelos.add(ModeloDocumento(
      id: m.id,
      nome: m.nome.trim(),
      tipo: atual?.tipo ?? m.tipo,
      corpo: m.corpo,
      versao: (atual?.versao ?? 0) + 1,
    ));
    notifyListeners();
    return null;
  }

  // ---------- documentos ----------

  /// Do mais recente para o mais antigo (ordem de inclusão).
  List<DocumentoClinico> documentosDoPaciente(String pacienteId, {String? profissionalId}) =>
      _documentos
          .where((d) =>
              d.pacienteId == pacienteId &&
              (profissionalId == null || d.profissionalId == profissionalId))
          .toList()
          .reversed
          .toList();

  DocumentoClinico? documentoPorId(String id) {
    for (final d in _documentos) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Ids dos documentos já corrigidos por outro.
  Set<String> retificados(String pacienteId) => {
        for (final d in _documentos)
          if (d.pacienteId == pacienteId && d.retificaId != null) d.retificaId!,
      };

  bool temHistorico(String pacienteId) => _documentos.any((d) => d.pacienteId == pacienteId);

  /// Devolve a mensagem de erro, ou null se incluiu.
  String? adicionarDocumento(DocumentoClinico d) {
    if (documentoPorId(d.id) != null) return 'Documento duplicado.';
    if (d.titulo.trim().isEmpty) return 'Informe o título do documento.';
    if (d.conteudo.trim().isEmpty) return 'O documento está vazio.';
    if (d.assinado) return 'Um documento novo começa como rascunho.';

    final a = _prontuario.atendimentoPorId(d.atendimentoId);
    if (a == null) return 'Atendimento não encontrado.';
    if (a.pacienteId != d.pacienteId) return 'Paciente diferente do atendimento.';
    if (a.profissionalId != d.profissionalId) {
      return 'Só o profissional do atendimento emite documentos nele.';
    }

    final alvo = d.retificaId;
    if (alvo == null) {
      if (a.encerrado) return 'O atendimento está encerrado.';
    } else {
      final anterior = documentoPorId(alvo);
      if (anterior == null || anterior.pacienteId != d.pacienteId) {
        return 'Documento a corrigir não encontrado.';
      }
      if (!anterior.assinado) return 'O documento ainda é rascunho: edite-o diretamente.';
      if (anterior.profissionalId != d.profissionalId) {
        return 'Só o autor do documento pode corrigi-lo.';
      }
      if (anterior.atendimentoId != d.atendimentoId) {
        return 'A correção deve ficar no mesmo atendimento do documento original.';
      }
      if (_documentos.any((x) => x.retificaId == alvo)) {
        return 'Este documento já foi corrigido.';
      }
      if ((d.justificativa ?? '').trim().length < 3) {
        return 'Informe a justificativa da correção.';
      }
    }

    _documentos.add(d);
    notifyListeners();
    return null;
  }

  /// Só rascunho pode mudar.
  String? atualizarRascunho(String id, String usuarioId, String novoConteudo) {
    final i = _documentos.indexWhere((d) => d.id == id);
    if (i < 0) return 'Documento não encontrado.';
    final d = _documentos[i];
    if (d.assinado) return 'Documento assinado não pode ser alterado. Emita uma correção (RN05).';
    if (d.profissionalId != usuarioId) return 'Só o autor altera o rascunho.';
    if (novoConteudo.trim().isEmpty) return 'O documento está vazio.';
    _documentos[i] = d.copiarCom(conteudo: novoConteudo.trim());
    notifyListeners();
    return null;
  }

  /// Descartar só vale para rascunho.
  String? descartarRascunho(String id, String usuarioId) {
    final i = _documentos.indexWhere((d) => d.id == id);
    if (i < 0) return 'Documento não encontrado.';
    final d = _documentos[i];
    if (d.assinado) return 'Documento assinado não pode ser excluído (RN05).';
    if (d.profissionalId != usuarioId) return 'Só o autor descarta o rascunho.';
    _documentos.removeAt(i);
    notifyListeners();
    return null;
  }

  String? assinarDocumento(String id, String usuarioId, {DateTime? agora}) {
    final i = _documentos.indexWhere((d) => d.id == id);
    if (i < 0) return 'Documento não encontrado.';
    final d = _documentos[i];
    if (d.assinado) return 'Documento já assinado.';
    if (d.profissionalId != usuarioId) return 'Só o autor assina o documento.';
    if (d.conteudo.contains(marcadorNaoPreenchido)) {
      return 'Há campos "$marcadorNaoPreenchido" no documento. Complete antes de assinar.';
    }
    final quando = agora ?? DateTime.now();
    _documentos[i] = d.copiarCom(
      assinado: true,
      assinadoEm: quando,
      selo: _selo(usuarioId, quando, d.conteudo),
    );
    notifyListeners();
    return null;
  }
}

final documentosRepository = DocumentosRepository(prontuario: prontuarioRepository);