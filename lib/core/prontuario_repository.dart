import 'package:flutter/foundation.dart';
import 'prontuario.dart';

/// Atendimentos, evoluções e adendos em memória (PROVISÓRIO).
///
/// Regras (RN05):
/// - evolução é rascunho até ser assinada; assinada, nunca mais muda;
/// - atendimento só encerra com todas as evoluções assinadas;
/// - correção de evolução assinada = adendo (datado, justificado e assinado);
/// - nada de clínico é excluído depois de assinado (só rascunho pode ser descartado).
///
/// ATENÇÃO: no servidor estas mesmas regras precisam ser repetidas.
class ProntuarioRepository extends ChangeNotifier {
  final List<Atendimento> _atendimentos = [];
  final List<Evolucao> _evolucoes = [];
  final List<Adendo> _adendos = [];
  int _contador = 0;

  String novoId() {
    _contador++;
    return 'pr${DateTime.now().microsecondsSinceEpoch}$_contador';
  }

  /// Selo provisório de integridade (não é assinatura digital).
  static String _selo(String autor, DateTime quando, String texto) {
    final h = Object.hashAll('$autor|${quando.toIso8601String()}|$texto'.codeUnits);
    return h.toUnsigned(32).toRadixString(16).padLeft(8, '0');
  }

  // ---------- consultas ----------

  /// Do mais recente para o mais antigo. [profissionalId] limita aos atendimentos
  /// daquela pessoa (cada profissional vê só o que ele mesmo registrou).
  List<Atendimento> atendimentosDoPaciente(String pacienteId, {String? profissionalId}) =>
      _atendimentos
          .where((a) =>
              a.pacienteId == pacienteId &&
              (profissionalId == null || a.profissionalId == profissionalId))
          .toList()
        ..sort((a, b) => b.inicio.compareTo(a.inicio));

  Atendimento? atendimentoPorId(String id) {
    for (final a in _atendimentos) {
      if (a.id == id) return a;
    }
    return null;
  }

  Atendimento? atendimentoAtivo(String pacienteId, String profissionalId) {
    for (final a in _atendimentos) {
      if (a.pacienteId == pacienteId && a.profissionalId == profissionalId && !a.encerrado) {
        return a;
      }
    }
    return null;
  }

  List<Evolucao> evolucoesDoAtendimento(String atendimentoId) =>
      _evolucoes.where((e) => e.atendimentoId == atendimentoId).toList()
        ..sort((a, b) => a.dataHora.compareTo(b.dataHora));

  Evolucao? _evolucao(String id) {
    for (final e in _evolucoes) {
      if (e.id == id) return e;
    }
    return null;
  }

  List<Adendo> adendosDaEvolucao(String evolucaoId) =>
      _adendos.where((a) => a.evolucaoId == evolucaoId).toList()
        ..sort((a, b) => a.dataHora.compareTo(b.dataHora));

  /// O paciente tem algum atendimento registrado? (usado para bloquear exclusão)
  bool temHistorico(String pacienteId) =>
      _atendimentos.any((a) => a.pacienteId == pacienteId);

  // ---------- atendimento ----------

  /// Devolve a mensagem de erro, ou null se deu certo.
  String? iniciarAtendimento(Atendimento a) {
    if (a.status != StatusAtendimento.emAtendimento || a.fim != null) {
      return 'Um atendimento novo começa "em atendimento".';
    }
    if (atendimentoPorId(a.id) != null) return 'Atendimento duplicado.';
    if (atendimentoAtivo(a.pacienteId, a.profissionalId) != null) {
      return 'Já existe um atendimento em aberto para este paciente.';
    }
    _atendimentos.add(a);
    notifyListeners();
    return null;
  }

  String? encerrarAtendimento(
    String id,
    String usuarioId, {
    String? observacoes,
    DateTime? agora,
  }) {
    final i = _atendimentos.indexWhere((a) => a.id == id);
    if (i < 0) return 'Atendimento não encontrado.';
    final a = _atendimentos[i];
    if (a.encerrado) return 'Este atendimento já foi encerrado.';
    if (a.profissionalId != usuarioId) return 'Só quem iniciou o atendimento pode encerrá-lo.';
    final pendentes = evolucoesDoAtendimento(id).where((e) => !e.assinada).length;
    if (pendentes > 0) {
      return 'Assine ou descarte os rascunhos antes de encerrar ($pendentes pendente(s)).';
    }
    final obs = (observacoes ?? '').trim();
    _atendimentos[i] = a.copiarCom(
      fim: agora ?? DateTime.now(),
      status: StatusAtendimento.encerrado,
      observacoesEncerramento: obs.isEmpty ? null : obs,
    );
    notifyListeners();
    return null;
  }

  // ---------- evolução ----------

  String? adicionarEvolucao(Evolucao e) {
    final a = atendimentoPorId(e.atendimentoId);
    if (a == null) return 'Atendimento não encontrado.';
    if (a.encerrado) return 'O atendimento está encerrado. Use um adendo para corrigir.';
    if (e.profissionalId != a.profissionalId) {
      return 'Só o profissional do atendimento registra evoluções nele.';
    }
    if (e.pacienteId != a.pacienteId) return 'Paciente diferente do atendimento.';
    if (e.assinada) return 'Uma evolução nova começa como rascunho.';
    if (e.texto.trim().isEmpty) return 'Escreva o texto da evolução.';
    if (_evolucao(e.id) != null) return 'Evolução duplicada.';
    _evolucoes.add(e);
    notifyListeners();
    return null;
  }

  /// Só rascunho pode mudar.
  String? atualizarRascunho(String id, String usuarioId, String novoTexto) {
    final i = _evolucoes.indexWhere((e) => e.id == id);
    if (i < 0) return 'Evolução não encontrada.';
    final e = _evolucoes[i];
    if (e.assinada) return 'Evolução assinada não pode ser alterada. Use um adendo (RN05).';
    if (e.profissionalId != usuarioId) return 'Só o autor altera o rascunho.';
    if (novoTexto.trim().isEmpty) return 'Escreva o texto da evolução.';
    _evolucoes[i] = e.copiarCom(texto: novoTexto.trim());
    notifyListeners();
    return null;
  }

  /// Descartar só vale para rascunho (nada assinado é apagado).
  String? descartarRascunho(String id, String usuarioId) {
    final i = _evolucoes.indexWhere((e) => e.id == id);
    if (i < 0) return 'Evolução não encontrada.';
    final e = _evolucoes[i];
    if (e.assinada) return 'Evolução assinada não pode ser excluída (RN05).';
    if (e.profissionalId != usuarioId) return 'Só o autor descarta o rascunho.';
    _evolucoes.removeAt(i);
    notifyListeners();
    return null;
  }

  String? assinarEvolucao(String id, String usuarioId, {DateTime? agora}) {
    final i = _evolucoes.indexWhere((e) => e.id == id);
    if (i < 0) return 'Evolução não encontrada.';
    final e = _evolucoes[i];
    if (e.assinada) return 'Evolução já assinada.';
    if (e.profissionalId != usuarioId) return 'Só o autor assina a evolução.';
    final quando = agora ?? DateTime.now();
    _evolucoes[i] = e.copiarCom(
      assinada: true,
      assinadaEm: quando,
      selo: _selo(usuarioId, quando, e.texto),
    );
    notifyListeners();
    return null;
  }

  // ---------- adendo ----------

  /// Cria o adendo já assinado. Só para evolução assinada, e só pelo autor dela.
  String? adicionarAdendo(Adendo a) {
    final e = _evolucao(a.evolucaoId);
    if (e == null) return 'Evolução não encontrada.';
    if (!e.assinada) return 'A evolução ainda é rascunho: edite-a diretamente.';
    if (a.profissionalId != e.profissionalId) return 'Só o autor da evolução cria adendo.';
    if (a.pacienteId != e.pacienteId) return 'Paciente diferente da evolução.';
    if (a.justificativa.trim().length < 3) return 'Informe a justificativa do adendo.';
    if (a.texto.trim().isEmpty) return 'Escreva o texto do adendo.';
    if (_adendos.any((x) => x.id == a.id)) return 'Adendo duplicado.';
    _adendos.add(a.copiarCom(
      assinado: true,
      selo: _selo(a.profissionalId, a.dataHora, a.texto),
    ));
    notifyListeners();
    return null;
  }
}

final prontuarioRepository = ProntuarioRepository();