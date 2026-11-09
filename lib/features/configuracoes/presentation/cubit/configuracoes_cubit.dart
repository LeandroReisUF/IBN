import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/agenda/data/agenda_service.dart';
import 'package:ibn/features/agenda/domain/sala.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/configuracoes/data/configuracao_repository.dart';
import 'package:ibn/features/configuracoes/domain/bloqueio_agenda.dart';
import 'configuracoes_state.dart';
import 'package:ibn/core/procedimento.dart';
import 'package:ibn/features/odontograma/data/odontograma_repository.dart';
import 'package:ibn/features/plano_tratamento/data/plano_repository.dart';
import 'package:ibn/features/auth/domain/perfil.dart';

/// Configurações da clínica vistas pelo Administrador.
/// As ações devolvem a mensagem de erro (ou null) e NÃO trocam o estado.
/// A trava de acesso é só uma segunda camada: no servidor a regra precisa ser repetida.
class ConfiguracoesCubit extends Cubit<ConfiguracoesState> {
    ConfiguracoesCubit({
    required ConfiguracaoRepository repositorio,
    required AgendaService agendaService,
    required Usuario usuario,
    PlanoRepository? planos,
    OdontogramaRepository? odontograma,
  })  : _repo = repositorio,
        _agenda = agendaService,
        _usuario = usuario,
        _planos = planos ?? planoRepository,
        _odonto = odontograma ?? odontogramas,
        super(const ConfiguracoesInitial()) {
    _repo.addListener(_aoMudarRepositorio);
  }

  final ConfiguracaoRepository _repo;
  final AgendaService _agenda;
  final Usuario _usuario;
  final PlanoRepository _planos;
  final OdontogramaRepository _odonto;

    ConfiguracoesSuccess _buscar() => ConfiguracoesSuccess(
      _repo.todasAsSalas, _repo.bloqueios, _repo.todosProcedimentos, _repo.coresPerfil);

  Future<void> carregar() async {
    emit(const ConfiguracoesLoading());
    try {
      emit(_buscar());
    } catch (_) {
      emit(const ConfiguracoesError('Não foi possível carregar as configurações.'));
    }
  }

  void _aoMudarRepositorio() {
    if (state is! ConfiguracoesSuccess || isClosed) return;
    try {
      emit(_buscar());
    } catch (_) {
      // Mantém o que já estava na tela.
    }
  }

  String? _semAcesso() => politicaAcesso.podeGerenciarConfiguracoes(_usuario)
      ? null
      : 'Só o Administrador gerencia as configurações da clínica.';

  void _log(String acao, String entidadeId) {
    logsAcesso.registrar(
      usuarioId: _usuario.id,
      acao: acao,
      entidade: 'configuracao',
      entidadeId: entidadeId,
    );
  }

  int get proximoNumeroSala => _repo.proximoNumeroSala;

  String novoId() => _repo.novoId();

  /// Agendamentos ativos já marcados na sala dentro do período do bloqueio.
  int agendamentosAfetados(BloqueioAgenda b) => _agenda.todos
      .where((a) =>
          a.status.ocupaHorario &&
          a.salaNumero == b.salaNumero &&
          AgendaService.sobrepoe(a.inicio, a.fim, b.inicio, b.fim))
      .length;

  // ---------- salas ----------

  Future<String?> salvarSala(Sala s) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.salvarSala(s);
    if (erro != null) return erro;
    _log('salvou_sala', '${s.numero}');
    return null;
  }

  Future<String?> definirSalaAtiva(int numero, bool ativa) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.definirSalaAtiva(numero, ativa);
    if (erro != null) return erro;
    _log(ativa ? 'ativou_sala' : 'desativou_sala', '$numero');
    return null;
  }

  Future<String?> excluirSala(int numero) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final emUso = _agenda.todos.any((a) => a.salaNumero == numero);
    final erro = _repo.excluirSala(numero, emUso: emUso);
    if (erro != null) return erro;
    _log('excluiu_sala', '$numero');
    return null;
  }

  // ---------- bloqueios ----------

  Future<String?> salvarBloqueio(BloqueioAgenda b) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.salvarBloqueio(b);
    if (erro != null) return erro;
    _log('salvou_bloqueio_sala', b.id);
    return null;
  }

  Future<String?> excluirBloqueio(String id) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.excluirBloqueio(id);
    if (erro != null) return erro;
    _log('desbloqueou_sala', id);
    return null;
  }

  @override
  Future<void> close() {
    _repo.removeListener(_aoMudarRepositorio);
    return super.close();
  }
    // ---------- procedimentos ----------

  bool _procedimentoEmUso(String id) =>
      _agenda.todos.any((a) => a.procedimentoId == id) ||
      _planos.usaProcedimento(id) ||
      _odonto.usaProcedimento(id);

  Future<String?> salvarProcedimento(Procedimento p) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.salvarProcedimento(p);
    if (erro != null) return erro;
    _log('salvou_procedimento', p.id);
    return null;
  }

  Future<String?> definirProcedimentoAtivo(String id, bool ativo) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.definirProcedimentoAtivo(id, ativo);
    if (erro != null) return erro;
    _log(ativo ? 'ativou_procedimento' : 'desativou_procedimento', id);
    return null;
  }

  Future<String?> excluirProcedimento(String id) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.excluirProcedimento(id, emUso: _procedimentoEmUso(id));
    if (erro != null) return erro;
    _log('excluiu_procedimento', id);
    return null;
  }
    // ---------- cores ----------

  Future<String?> definirCorPerfil(Perfil perfil, int cor) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.definirCorPerfil(perfil, cor);
    if (erro != null) return erro;
    _log('definiu_cor_tipo_profissional', perfil.name);
    return null;
  }

  Future<String?> restaurarCores() async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    _repo.restaurarCoresPadrao();
    _log('restaurou_cores_padrao', 'todas');
    return null;
  }
}