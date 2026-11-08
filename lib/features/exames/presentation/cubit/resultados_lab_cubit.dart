import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/exames/data/resultados_lab_repository.dart';
import 'package:ibn/features/exames/domain/exames.dart';
import 'package:ibn/features/exames/domain/resultado_exame.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';

/// Estados dos resultados laboratoriais de UM exame.
sealed class ResultadosLabState {
  const ResultadosLabState();
}

final class ResultadosLabInitial extends ResultadosLabState {
  const ResultadosLabInitial();
}

final class ResultadosLabLoading extends ResultadosLabState {
  const ResultadosLabLoading();
}

/// [resultados] em ordem de inclusão; [substituidos]: ids já corrigidos por outro.
final class ResultadosLabSuccess extends ResultadosLabState {
  final List<ResultadoExame> resultados;
  final Set<String> substituidos;
  const ResultadosLabSuccess(this.resultados, this.substituidos);

  /// Resultados em vigor que estão fora do padrão.
  List<ResultadoExame> get alertas =>
      resultados.where((r) => !substituidos.contains(r.id) && r.dados.foraDoPadrao).toList();
}

final class ResultadosLabError extends ResultadosLabState {
  final String mensagem;
  const ResultadosLabError(this.mensagem);
}

/// Resultados laboratoriais de um exame, vistos por quem o solicitou.
/// As ações devolvem a mensagem de erro (ou null) e NÃO trocam o estado.
class ResultadosLabCubit extends Cubit<ResultadosLabState> {
  ResultadosLabCubit({
    required ResultadosLabRepository repositorio,
    required Usuario usuario,
    required Paciente paciente,
    required Exame exame,
  })  : _repo = repositorio,
        _usuario = usuario,
        _paciente = paciente,
        _exame = exame,
        super(const ResultadosLabInitial()) {
    _repo.addListener(_aoMudarRepositorio);
  }

  final ResultadosLabRepository _repo;
  final Usuario _usuario;
  final Paciente _paciente;
  final Exame _exame;

  ResultadosLabSuccess _buscar() => ResultadosLabSuccess(
        _repo.resultadosDoExame(_exame.id),
        _repo.substituidos(_exame.id),
      );

  Future<void> carregar() async {
    emit(const ResultadosLabLoading());
    try {
      emit(_buscar());
    } catch (_) {
      emit(const ResultadosLabError('Não foi possível carregar os resultados.'));
    }
  }

  void _aoMudarRepositorio() {
    if (state is! ResultadosLabSuccess || isClosed) return;
    try {
      emit(_buscar());
    } catch (_) {
      // Mantém o que já estava na tela.
    }
  }

  /// Lança um resultado novo; com [anterior], ele corrige aquele (RN05).
  Future<String?> registrar(
    ResultadoLab dados, {
    ResultadoExame? anterior,
    String? justificativa,
  }) async {
    if (!politicaAcesso.podeEditarExames(_usuario, _paciente)) {
      return 'Você não tem permissão para lançar resultados deste paciente.';
    }
    final erro = _repo.adicionarResultado(ResultadoExame(
      id: _repo.novoId(),
      exameId: _exame.id,
      pacienteId: _paciente.id,
      dados: dados,
      profissionalId: _usuario.id,
      registradoEm: DateTime.now(),
      retificaId: anterior?.id,
      justificativa: justificativa,
    ));
    if (erro != null) return erro;
    logsAcesso.registrar(
      usuarioId: _usuario.id,
      acao: anterior == null ? 'lancou_resultado_exame' : 'corrigiu_resultado_exame',
      entidade: 'paciente',
      entidadeId: _paciente.id,
    );
    return null;
  }

  @override
  Future<void> close() {
    _repo.removeListener(_aoMudarRepositorio);
    return super.close();
  }
}