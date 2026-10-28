import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/features/agenda/data/agenda_service.dart';
import 'package:ibn/features/agenda/domain/agendamento.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'agendamento_state.dart';

/// Gerencia o estado da agenda (Initial → Loading → Success | Error).
///
/// Por enquanto envolve o [AgendaService] que já existe (dados em memória e
/// regras RN01/RN02). Quando houver API, só o método [_buscar] e as ações
/// mudam; a tela continua igual.
class AgendamentoCubit extends Cubit<AgendamentoState> {
  AgendamentoCubit({required AgendaService servico, required Usuario usuario})
      : _servico = servico,
        _usuario = usuario,
        super(const AgendamentoInitial()) {
    // Outras telas (ex.: Prontuário) também mexem na agenda. Ouvir o serviço
    // mantém esta tela atualizada durante a migração.
    _servico.addListener(_aoMudarServico);
  }

  final AgendaService _servico;
  final Usuario _usuario;

  /// RN03: cada perfil só recebe os agendamentos que pode ver.
  Future<List<Agendamento>> _buscar() async =>
      politicaAcesso.filtrarAgenda(_usuario, _servico.todos);

  Future<void> carregar() async {
    emit(const AgendamentoLoading());
    try {
      emit(AgendamentoSuccess(await _buscar()));
    } catch (_) {
      emit(const AgendamentoError('Não foi possível carregar a agenda.'));
    }
  }

  void _aoMudarServico() {
    // Só atualiza se já tinha carregado; evita "ressuscitar" um estado de erro.
    if (state is AgendamentoSuccess) _atualizarSemLoading();
  }

  Future<void> _atualizarSemLoading() async {
    try {
      final lista = await _buscar();
      if (!isClosed) emit(AgendamentoSuccess(lista));
    } catch (_) {
      // Mantém a lista que já estava na tela.
    }
  }

  // ---------- ações ----------
  // Devolvem a mensagem de erro de regra (conflito de sala, etc.) ou null se
  // deu certo. Erro de regra NÃO troca o estado: a lista continua na tela e a
  // UI mostra um SnackBar. Em caso de sucesso o serviço avisa e a lista recarrega.

  Future<String?> criar(Agendamento a) async => _servico.criar(a);

  Future<String?> atualizar(Agendamento a) async => _servico.atualizar(a);

  Future<String?> mudarStatus(String id, StatusAgendamento status) async =>
      _servico.mudarStatus(id, status);

  /// Validação ao vivo do formulário (sem salvar).
  String? validarConflitos(Agendamento a) => _servico.validarConflitos(a);

  @override
  Future<void> close() {
    _servico.removeListener(_aoMudarServico);
    return super.close();
  }
}