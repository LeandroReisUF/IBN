import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/auth/data/auth_service.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/pacientes/data/paciente_repository.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/plano_tratamento/data/plano_repository.dart';
import 'package:ibn/features/plano_tratamento/domain/plano_tratamento.dart';
import 'plano_state.dart';

/// Plano de tratamento de UM paciente, visto pelo profissional logado (RN04).
/// Initial → Loading → Success | Error.
///
/// RN04: o estado só carrega os planos que o usuário CRIOU (com valores) e as
/// guias dos procedimentos encaminhados a ele (sem valores). Quem só executa
/// nunca recebe dinheiro no estado.
///
/// As ações devolvem a mensagem de erro (ou null) e NÃO trocam o estado.
/// A trava de acesso aqui é só uma segunda camada: no servidor a regra
/// precisa ser repetida.
class PlanoCubit extends Cubit<PlanoState> {
  PlanoCubit({
    required PlanoRepository repositorio,
    required PacienteRepository pacientes,
    required Usuario usuario,
    required Paciente paciente,
  })  : _repo = repositorio,
        _pacientes = pacientes,
        _usuario = usuario,
        _paciente = paciente,
        super(const PlanoInitial()) {
    _repo.addListener(_aoMudarRepositorio);
  }

  final PlanoRepository _repo;
  final PacienteRepository _pacientes;
  final Usuario _usuario;
  final Paciente _paciente;

  // ---------- carregamento ----------

  Future<PlanoSuccess> _buscar() async => PlanoSuccess(
        _repo.planosDoPaciente(_paciente.id, criadorId: _usuario.id),
        _repo.guiasDoExecutante(_paciente.id, _usuario.id),
      );

  Future<void> carregar() async {
    emit(const PlanoLoading());
    try {
      emit(await _buscar());
    } catch (_) {
      emit(const PlanoError('Não foi possível carregar o plano de tratamento.'));
    }
  }

  void _aoMudarRepositorio() {
    if (state is PlanoSuccess) _atualizarSemLoading();
  }

  Future<void> _atualizarSemLoading() async {
    try {
      final novo = await _buscar();
      if (!isClosed) emit(novo);
    } catch (_) {
      // Mantém o que já estava na tela.
    }
  }

  // ---------- utilidades ----------

  String? _semAcessoPlanejar() => politicaAcesso.podePlanejarTratamento(_usuario, _paciente)
      ? null
      : 'Você não tem permissão para planejar tratamento deste paciente.';

  String? _semAcessoExecutar() => politicaAcesso.podeExecutarProcedimento(_usuario, _paciente)
      ? null
      : 'Você não tem permissão para executar procedimentos deste paciente.';

  void _log(String acao) {
    logsAcesso.registrar(
      usuarioId: _usuario.id,
      acao: acao,
      entidade: 'paciente',
      entidadeId: _paciente.id,
    );
  }

  /// Dentistas que podem receber um encaminhamento (todos menos o próprio usuário).
  List<Usuario> get executantesPossiveis => [
        for (final u in auth.profissionaisSaude)
          if (u.perfil == Perfil.dentista && u.id != _usuario.id) u,
      ];

  // ---------- plano ----------

  Future<String?> criarPlano(String titulo) async {
    final sem = _semAcessoPlanejar();
    if (sem != null) return sem;
    final erro = _repo.criarPlano(PlanoTratamento(
      id: _repo.novoId(),
      pacienteId: _paciente.id,
      criadorId: _usuario.id,
      titulo: titulo,
      criadoEm: DateTime.now(),
    ));
    if (erro != null) return erro;
    _log('criou_plano_tratamento');
    return null;
  }

  Future<String?> adicionarItem(
    PlanoTratamento plano, {
    required String procedimentoId,
    int? dente,
    String instrucoes = '',
    required int valorCentavos,
    int descontoCentavos = 0,
  }) async {
    final sem = _semAcessoPlanejar();
    if (sem != null) return sem;
    final erro = _repo.adicionarItem(
      plano.id,
      _usuario.id,
      ItemPlano(
        id: _repo.novoId(),
        procedimentoId: procedimentoId,
        dente: dente,
        instrucoes: instrucoes.trim(),
        valorCentavos: valorCentavos,
        descontoCentavos: descontoCentavos,
      ),
    );
    if (erro != null) return erro;
    _log('adicionou_item_plano');
    return null;
  }

  Future<String?> definirOrcamento(PlanoTratamento plano, FormaPagamento forma, int parcelas) async {
    final sem = _semAcessoPlanejar();
    if (sem != null) return sem;
    final erro = _repo.definirOrcamento(
        plano.id, _usuario.id, Orcamento(forma: forma, parcelas: parcelas));
    if (erro != null) return erro;
    _log('definiu_orcamento');
    return null;
  }

  Future<String?> cancelarItem(PlanoTratamento plano, ItemPlano item) async {
    final sem = _semAcessoPlanejar();
    if (sem != null) return sem;
    final erro = _repo.cancelarItem(plano.id, item.id, _usuario.id);
    if (erro != null) return erro;
    _log('cancelou_item_plano');
    return null;
  }

  /// O criador marca como realizado um procedimento que ele mesmo executou.
  Future<String?> realizarMeuItem(PlanoTratamento plano, ItemPlano item) async {
    final sem = _semAcessoPlanejar();
    if (sem != null) return sem;
    final erro = _repo.realizarItem(plano.id, item.id, _usuario.id);
    if (erro != null) return erro;
    _log('realizou_procedimento_plano');
    return null;
  }

  /// Encaminha o procedimento a outro dentista. O paciente é vinculado a ele
  /// (vínculo manual de encaminhamento, RN03), senão ele não abriria o prontuário.
  Future<String?> encaminhar(
    PlanoTratamento plano,
    ItemPlano item,
    String executanteId, {
    String instrucoes = '',
  }) async {
    final sem = _semAcessoPlanejar();
    if (sem != null) return sem;
    final executante = auth.buscarPorId(executanteId);
    if (executante == null || executante.perfil != Perfil.dentista) {
      return 'Escolha um dentista para executar o procedimento.';
    }
    final erro = _repo.encaminharItem(
      plano.id,
      item.id,
      _usuario.id,
      executanteId,
      instrucoes: instrucoes,
    );
    if (erro != null) return erro;
    final p = _pacientes.buscarPorId(_paciente.id);
    if (p != null && !p.profissionaisVinculados.contains(executanteId)) {
      _pacientes.salvar(p.copiarCom(
        profissionaisVinculados: {...p.profissionaisVinculados, executanteId},
      ));
    }
    _log('encaminhou_procedimento');
    return null;
  }

  // ---------- executante ----------

  /// O executante marca como realizado o procedimento encaminhado a ele.
  Future<String?> executarGuia(GuiaProcedimentoExecutante guia) async {
    final sem = _semAcessoExecutar();
    if (sem != null) return sem;
    final erro = _repo.realizarItem(guia.planoId, guia.itemId, _usuario.id);
    if (erro != null) return erro;
    _log('realizou_procedimento_encaminhado');
    return null;
  }

  @override
  Future<void> close() {
    _repo.removeListener(_aoMudarRepositorio);
    return super.close();
  }
}