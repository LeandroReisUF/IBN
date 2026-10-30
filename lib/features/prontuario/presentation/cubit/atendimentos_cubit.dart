import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/agenda/data/agenda_service.dart';
import 'package:ibn/features/agenda/domain/agendamento.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'package:ibn/features/prontuario/domain/prontuario.dart';
import 'atendimentos_state.dart';

/// Atendimentos de UM paciente, vistos pelo profissional logado.
/// Initial → Loading → Success | Error.
///
/// Concentra o que antes ficava espalhado na tela: ligar o atendimento ao
/// agendamento de hoje, mudar o status na agenda e registrar o log de acesso
/// (RNF03). As regras da RN05 (rascunho, assinatura, adendo) continuam no
/// [ProntuarioRepository] e precisam ser repetidas no servidor.
///
/// As ações devolvem a mensagem de erro (ou null) e NÃO trocam o estado.
class AtendimentosCubit extends Cubit<AtendimentosState> {
  AtendimentosCubit({
    required ProntuarioRepository repositorio,
    required AgendaService agendaService,
    required Usuario usuario,
    required Paciente paciente,
  })  : _repo = repositorio,
        _agenda = agendaService,
        _usuario = usuario,
        _paciente = paciente,
        super(const AtendimentosInitial()) {
    _repo.addListener(_aoMudarRepositorio);
  }

  final ProntuarioRepository _repo;
  final AgendaService _agenda;
  final Usuario _usuario;
  final Paciente _paciente;

  // ---------- carregamento ----------

  /// Cada profissional vê só os atendimentos que ele mesmo registrou (RN03).
  Future<List<AtendimentoDetalhe>> _buscar() async {
    final atendimentos =
        _repo.atendimentosDoPaciente(_paciente.id, profissionalId: _usuario.id);
    return [
      for (final a in atendimentos)
        AtendimentoDetalhe(a, [
          for (final e in _repo.evolucoesDoAtendimento(a.id))
            EvolucaoComAdendos(e, _repo.adendosDaEvolucao(e.id)),
        ]),
    ];
  }

  Future<void> carregar() async {
    emit(const AtendimentosLoading());
    try {
      emit(AtendimentosSuccess(await _buscar()));
    } catch (_) {
      emit(const AtendimentosError('Não foi possível carregar os atendimentos.'));
    }
  }

  void _aoMudarRepositorio() {
    if (state is AtendimentosSuccess) _atualizarSemLoading();
  }

  Future<void> _atualizarSemLoading() async {
    try {
      final lista = await _buscar();
      if (!isClosed) emit(AtendimentosSuccess(lista));
    } catch (_) {
      // Mantém a lista que já estava na tela.
    }
  }

  // ---------- utilidades ----------

  String? _semAcesso() => politicaAcesso.podeAcessarProntuario(_usuario, _paciente)
      ? null
      : 'Você não tem acesso ao prontuário deste paciente.';

  void _log(String acao, String atendimentoId) {
    logsAcesso.registrar(
      usuarioId: _usuario.id,
      acao: acao,
      entidade: 'atendimento',
      entidadeId: atendimentoId,
    );
  }

  /// Agendamentos de hoje deste paciente com este profissional que ainda podem
  /// ser ligados a um atendimento novo (a tela oferece a escolha).
  List<Agendamento> agendamentosIniciaveisHoje({DateTime? agora}) {
    const iniciaveis = [
      StatusAgendamento.agendado,
      StatusAgendamento.confirmadoWhatsapp,
      StatusAgendamento.naRecepcao,
    ];
    final hoje = soData(agora ?? DateTime.now());
    return _agenda.todos
        .where((a) =>
            a.pacienteId == _paciente.id &&
            a.profissionalId == _usuario.id &&
            mesmoDia(a.inicio, hoje) &&
            iniciaveis.contains(a.status))
        .toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
  }

  // ---------- atendimento ----------

  /// Inicia um atendimento. Com [agendamentoId], o status do agendamento
  /// passa para "Em atendimento".
  Future<String?> iniciar({String? agendamentoId, DateTime? agora}) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final atendimento = Atendimento(
      id: _repo.novoId(),
      pacienteId: _paciente.id,
      profissionalId: _usuario.id,
      agendamentoId: agendamentoId,
      inicio: agora ?? DateTime.now(),
    );
    final erro = _repo.iniciarAtendimento(atendimento);
    if (erro != null) return erro;
    if (agendamentoId != null) {
      _agenda.mudarStatus(agendamentoId, StatusAgendamento.emAtendimento);
    }
    _log('iniciou_atendimento', atendimento.id);
    return null;
  }

  /// Encerra o atendimento (todas as evoluções precisam estar assinadas).
  /// Se havia agendamento, ele passa para "Atendido".
  Future<String?> encerrar(String atendimentoId, {String? observacoes}) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final atendimento = _repo.atendimentoPorId(atendimentoId);
    final erro = _repo.encerrarAtendimento(atendimentoId, _usuario.id, observacoes: observacoes);
    if (erro != null) return erro;
    final ag = atendimento?.agendamentoId;
    if (ag != null) _agenda.mudarStatus(ag, StatusAgendamento.atendido);
    _log('encerrou_atendimento', atendimentoId);
    return null;
  }

  // ---------- evolução ----------

  Future<String?> adicionarEvolucao(
    String atendimentoId,
    TipoEvolucao tipo,
    String texto,
  ) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.adicionarEvolucao(Evolucao(
      id: _repo.novoId(),
      atendimentoId: atendimentoId,
      pacienteId: _paciente.id,
      profissionalId: _usuario.id,
      tipo: tipo,
      texto: texto,
      dataHora: DateTime.now(),
    ));
    if (erro != null) return erro;
    _log('registrou_evolucao', atendimentoId);
    return null;
  }

  Future<String?> atualizarRascunho(Evolucao e, String novoTexto) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    return _repo.atualizarRascunho(e.id, _usuario.id, novoTexto);
  }

  Future<String?> descartarRascunho(Evolucao e) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    return _repo.descartarRascunho(e.id, _usuario.id);
  }

  Future<String?> assinar(Evolucao e) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.assinarEvolucao(e.id, _usuario.id);
    if (erro != null) return erro;
    _log('assinou_evolucao', e.atendimentoId);
    return null;
  }

  // ---------- adendo ----------

  /// Cria o adendo (já assinado) para corrigir uma evolução assinada (RN05).
  Future<String?> adicionarAdendo(Evolucao e, String justificativa, String texto) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.adicionarAdendo(Adendo(
      id: _repo.novoId(),
      evolucaoId: e.id,
      pacienteId: _paciente.id,
      profissionalId: _usuario.id,
      justificativa: justificativa,
      texto: texto,
      dataHora: DateTime.now(),
    ));
    if (erro != null) return erro;
    _log('registrou_adendo', e.atendimentoId);
    return null;
  }

  @override
  Future<void> close() {
    _repo.removeListener(_aoMudarRepositorio);
    return super.close();
  }
}