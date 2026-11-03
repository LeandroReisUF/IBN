import 'package:flutter/foundation.dart';
import 'package:ibn/core/especialidade.dart';
import 'package:ibn/features/anamnese/domain/anamnese.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';

/// Modelos e anamneses em memória (PROVISÓRIO).
///
/// Regras (RN05):
/// - a anamnese nasce como rascunho (pode editar ou descartar) e só se assina
///   com todas as perguntas obrigatórias respondidas;
/// - assinada, nunca mais muda: atualizar = nova anamnese que aponta para a
///   anterior, e a anterior continua no histórico;
/// - um rascunho por paciente, autor e modelo de cada vez.
///
/// ATENÇÃO: no servidor estas mesmas regras precisam ser repetidas.
class AnamneseRepository extends ChangeNotifier {
  AnamneseRepository({
    required ProntuarioRepository prontuario,
    List<ModeloAnamnese> modelos = modelosAnamnesePadrao,
  })  : _prontuario = prontuario,
        _modelos = List.of(modelos);

  final ProntuarioRepository _prontuario;
  final List<ModeloAnamnese> _modelos;
  final List<Anamnese> _anamneses = [];
  int _contador = 0;

  String novoId() {
    _contador++;
    return 'an${DateTime.now().microsecondsSinceEpoch}$_contador';
  }

  /// Selo provisório de integridade (não é assinatura digital).
  static String _selo(String autor, DateTime quando, String texto) {
    final h = Object.hashAll('$autor|${quando.toIso8601String()}|$texto'.codeUnits);
    return h.toUnsigned(32).toRadixString(16).padLeft(8, '0');
  }

  // ---------- consultas ----------

  List<ModeloAnamnese> get modelos => List.unmodifiable(_modelos);

  ModeloAnamnese? modeloPorId(String id) {
    for (final m in _modelos) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Do mais recente para o mais antigo (ordem de inclusão).
  List<Anamnese> anamnesesDoPaciente(String pacienteId, {String? profissionalId}) => _anamneses
      .where((a) =>
          a.pacienteId == pacienteId &&
          (profissionalId == null || a.profissionalId == profissionalId))
      .toList()
      .reversed
      .toList();
  /// O que [profissionalId] pode ver: as suas (inclusive rascunhos) e as ASSINADAS
  /// de colegas da mesma especialidade do modelo. Modelo geral não é compartilhado.
  List<Anamnese> anamnesesVisiveis(
    String pacienteId, {
    required String profissionalId,
    required Set<Especialidade> especialidades,
  }) =>
      anamnesesDoPaciente(pacienteId).where((a) {
        if (a.profissionalId == profissionalId) return true;
        final esp = modeloPorId(a.modeloId)?.especialidade;
        return a.assinada && esp != null && especialidades.contains(esp);
      }).toList();
  Anamnese? porId(String id) {
    for (final a in _anamneses) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Ids das anamneses já atualizadas por uma versão mais nova.
  Set<String> substituidas(String pacienteId) => {
        for (final a in _anamneses)
          if (a.pacienteId == pacienteId && a.anteriorId != null) a.anteriorId!,
      };

  bool temHistorico(String pacienteId) => _anamneses.any((a) => a.pacienteId == pacienteId);

  // ---------- anamnese ----------

  /// Devolve a mensagem de erro, ou null se incluiu.
  String? adicionarAnamnese(Anamnese a) {
    if (porId(a.id) != null) return 'Anamnese duplicada.';
    if (a.perguntas.isEmpty) return 'A anamnese não tem perguntas.';
    if (a.assinada) return 'Uma anamnese nova começa como rascunho.';

    final atendimentoId = a.atendimentoId;
    if (atendimentoId != null) {
      final at = _prontuario.atendimentoPorId(atendimentoId);
      if (at == null) return 'Atendimento não encontrado.';
      if (at.pacienteId != a.pacienteId) return 'Paciente diferente do atendimento.';
      if (at.profissionalId != a.profissionalId) {
        return 'Só o profissional do atendimento registra anamnese nele.';
      }
    }

    final anteriorId = a.anteriorId;
    if (anteriorId != null) {
      final anterior = porId(anteriorId);
      if (anterior == null || anterior.pacienteId != a.pacienteId) {
        return 'Anamnese anterior não encontrada.';
      }
      if (!anterior.assinada) return 'A anamnese anterior ainda é rascunho: edite-a diretamente.';
      if (anterior.profissionalId != a.profissionalId) {
        return 'Só o autor da anamnese pode atualizá-la.';
      }
      if (anterior.modeloId != a.modeloId) return 'A atualização deve usar o mesmo modelo.';
      if (_anamneses.any((x) => x.anteriorId == anteriorId)) {
        return 'Esta anamnese já foi atualizada.';
      }
    }

    final jaTemRascunho = _anamneses.any((x) =>
        !x.assinada &&
        x.pacienteId == a.pacienteId &&
        x.profissionalId == a.profissionalId &&
        x.modeloId == a.modeloId);
    if (jaTemRascunho) return 'Já existe um rascunho desta anamnese. Continue-o ou descarte-o.';

    final erro = validarRespostas(a.perguntas, a.respostas);
    if (erro != null) return erro;

    _anamneses.add(a);
    notifyListeners();
    return null;
  }

  /// Só rascunho pode mudar.
  String? atualizarRascunho(String id, String usuarioId, Map<String, String> respostas) {
    final i = _anamneses.indexWhere((a) => a.id == id);
    if (i < 0) return 'Anamnese não encontrada.';
    final a = _anamneses[i];
    if (a.assinada) return 'Anamnese assinada não pode ser alterada. Crie uma nova versão (RN05).';
    if (a.profissionalId != usuarioId) return 'Só o autor altera o rascunho.';
    final erro = validarRespostas(a.perguntas, respostas);
    if (erro != null) return erro;
    _anamneses[i] = a.copiarCom(respostas: Map.of(respostas));
    notifyListeners();
    return null;
  }

  /// Descartar só vale para rascunho.
  String? descartarRascunho(String id, String usuarioId) {
    final i = _anamneses.indexWhere((a) => a.id == id);
    if (i < 0) return 'Anamnese não encontrada.';
    final a = _anamneses[i];
    if (a.assinada) return 'Anamnese assinada não pode ser excluída (RN05).';
    if (a.profissionalId != usuarioId) return 'Só o autor descarta o rascunho.';
    _anamneses.removeAt(i);
    notifyListeners();
    return null;
  }

  String? assinarAnamnese(String id, String usuarioId, {DateTime? agora}) {
    final i = _anamneses.indexWhere((a) => a.id == id);
    if (i < 0) return 'Anamnese não encontrada.';
    final a = _anamneses[i];
    if (a.assinada) return 'Anamnese já assinada.';
    if (a.profissionalId != usuarioId) return 'Só o autor assina a anamnese.';
    final faltando = faltandoObrigatorias(a.perguntas, a.respostas);
    if (faltando.isNotEmpty) return 'Responda: ${faltando.join('; ')}.';
    final quando = agora ?? DateTime.now();
    final resumo = (a.respostas.entries.toList()..sort((x, y) => x.key.compareTo(y.key)))
        .map((e) => '${e.key}=${e.value}')
        .join(';');
    _anamneses[i] = a.copiarCom(
      assinada: true,
      assinadaEm: quando,
      selo: _selo(usuarioId, quando, resumo),
    );
    notifyListeners();
    return null;
  }
}

final anamneseRepository = AnamneseRepository(prontuario: prontuarioRepository);