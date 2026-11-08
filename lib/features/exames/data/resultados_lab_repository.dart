import 'package:flutter/foundation.dart';
import 'package:ibn/features/exames/data/exames_repository.dart';
import 'package:ibn/features/exames/domain/exames.dart';
import 'package:ibn/features/exames/domain/resultado_exame.dart';

/// Resultados laboratoriais estruturados, em memória (PROVISÓRIO).
///
/// Regras:
/// - só quem solicitou o exame lança resultados, e exame cancelado não recebe;
/// - analito e unidade obrigatórios; valor finito; referência mínima não pode
///   passar da máxima;
/// - RN05: só inclusão. Corrigir = novo resultado que retifica o anterior, do
///   mesmo exame e com justificativa.
///
/// ATENÇÃO: no servidor estas mesmas regras precisam ser repetidas.
class ResultadosLabRepository extends ChangeNotifier {
  ResultadosLabRepository({required ExamesRepository exames}) : _exames = exames;

  final ExamesRepository _exames;
  final List<ResultadoExame> _resultados = [];
  int _contador = 0;

  String novoId() {
    _contador++;
    return 'rl${DateTime.now().microsecondsSinceEpoch}$_contador';
  }

  /// Em ordem de inclusão.
  List<ResultadoExame> resultadosDoExame(String exameId) =>
      _resultados.where((r) => r.exameId == exameId).toList();

  /// Ids de resultados já substituídos por outro.
  Set<String> substituidos(String exameId) => {
        for (final r in _resultados)
          if (r.exameId == exameId && r.retificaId != null) r.retificaId!,
      };

  /// Resultados em vigor (não substituídos) fora do padrão: são os alertas.
  List<ResultadoExame> alertasDoExame(String exameId) {
    final subst = substituidos(exameId);
    return resultadosDoExame(exameId)
        .where((r) => !subst.contains(r.id) && r.dados.foraDoPadrao)
        .toList();
  }

  /// Devolve a mensagem de erro, ou null se incluiu.
  String? adicionarResultado(ResultadoExame r) {
    final exame = _exames.examePorId(r.exameId);
    if (exame == null) return 'Exame não encontrado.';
    if (exame.pacienteId != r.pacienteId) return 'Paciente diferente do exame.';
    if (exame.profissionalId != r.profissionalId) {
      return 'Só quem solicitou o exame lança resultados.';
    }
    if (exame.status == StatusExame.cancelado) return 'Exame cancelado não recebe resultados.';
    if (_resultados.any((x) => x.id == r.id)) return 'Resultado duplicado.';

    final d = r.dados;
    if (d.analito.trim().isEmpty) return 'Informe o analito.';
    if (d.unidade.trim().isEmpty) return 'Informe a unidade.';
    if (!d.valor.isFinite) return 'Valor inválido.';
    final min = d.refMin;
    final max = d.refMax;
    if (min != null && max != null && min > max) {
      return 'A referência mínima não pode passar da máxima.';
    }

    final alvo = r.retificaId;
    if (alvo != null) {
      ResultadoExame? anterior;
      for (final x in _resultados) {
        if (x.id == alvo) anterior = x;
      }
      if (anterior == null || anterior.exameId != r.exameId) {
        return 'Resultado a corrigir não encontrado.';
      }
      if (_resultados.any((x) => x.retificaId == alvo)) {
        return 'Este resultado já foi corrigido.';
      }
      if ((r.justificativa ?? '').trim().length < 3) {
        return 'Informe a justificativa da correção.';
      }
    }

    _resultados.add(r);
    notifyListeners();
    return null;
  }
}

final resultadosLabRepository = ResultadosLabRepository(exames: examesRepository);