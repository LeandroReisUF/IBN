import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/core/lote_aplicado.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/biomedicina/data/biomedicina_repository.dart';
import 'package:ibn/features/biomedicina/domain/biomedicina.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'biomedicina_state.dart';

/// Procedimentos estéticos de UM paciente, vistos pelo biomédico logado.
/// Initial → Loading → Success | Error.
///
/// As ações devolvem a mensagem de erro (ou null) e NÃO trocam o estado.
/// A trava de acesso aqui é só uma segunda camada: no servidor a regra
/// precisa ser repetida.
class BiomedicinaCubit extends Cubit<BiomedicinaState> {
  BiomedicinaCubit({
    required BiomedicinaRepository repositorio,
    required ProntuarioRepository prontuario,
    required Usuario usuario,
    required Paciente paciente,
  })  : _repo = repositorio,
        _prontuario = prontuario,
        _usuario = usuario,
        _paciente = paciente,
        super(const BiomedicinaInitial()) {
    _repo.addListener(_aoMudarRepositorio);
  }

  final BiomedicinaRepository _repo;
  final ProntuarioRepository _prontuario;
  final Usuario _usuario;
  final Paciente _paciente;

  // ---------- carregamento ----------

  Future<BiomedicinaSuccess> _buscar() async => BiomedicinaSuccess(
        _repo.procedimentosDoPaciente(_paciente.id, profissionalId: _usuario.id),
        _repo.retificados(_paciente.id),
      );

  Future<void> carregar() async {
    emit(const BiomedicinaLoading());
    try {
      emit(await _buscar());
    } catch (_) {
      emit(const BiomedicinaError('Não foi possível carregar os procedimentos.'));
    }
  }

  void _aoMudarRepositorio() {
    if (state is BiomedicinaSuccess) _atualizarSemLoading();
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

  String? _semAcesso() => politicaAcesso.podeEditarProcedimentosEsteticos(_usuario, _paciente)
      ? null
      : 'Você não tem permissão para registrar procedimentos estéticos deste paciente.';

  void _log(String acao) {
    logsAcesso.registrar(
      usuarioId: _usuario.id,
      acao: acao,
      entidade: 'paciente',
      entidadeId: _paciente.id,
    );
  }

  bool get temAtendimentoAberto =>
      _prontuario.atendimentoAtivo(_paciente.id, _usuario.id) != null;

  // ---------- procedimentos ----------

  Future<String?> registrar({
    required TipoProtocolo protocolo,
    String? protocoloOutro,
    required String regiaoTratada,
    String parametros = '',
    required List<LoteAplicado> insumos,
    String observacoes = '',
  }) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final atendimento = _prontuario.atendimentoAtivo(_paciente.id, _usuario.id);
    if (atendimento == null) {
      return 'Inicie um atendimento na aba Atendimentos antes de registrar o procedimento.';
    }
    final erro = _repo.adicionarProcedimento(ProcedimentoEstetico(
      id: _repo.novoId(),
      pacienteId: _paciente.id,
      atendimentoId: atendimento.id,
      profissionalId: _usuario.id,
      protocolo: protocolo,
      protocoloOutro: protocoloOutro,
      regiaoTratada: regiaoTratada.trim(),
      parametros: parametros.trim(),
      insumos: insumos,
      observacoes: observacoes.trim(),
      dataHora: DateTime.now(),
    ));
    if (erro != null) return erro;
    _log('registrou_procedimento_estetico');
    return null;
  }

  /// Corrige um registro: o anterior fica riscado e este passa a valer (RN05).
  Future<String?> retificar(
    ProcedimentoEstetico anterior, {
    required TipoProtocolo protocolo,
    String? protocoloOutro,
    required String regiaoTratada,
    String parametros = '',
    required List<LoteAplicado> insumos,
    String observacoes = '',
    required String justificativa,
  }) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.adicionarProcedimento(ProcedimentoEstetico(
      id: _repo.novoId(),
      pacienteId: _paciente.id,
      atendimentoId: anterior.atendimentoId,
      profissionalId: _usuario.id,
      protocolo: protocolo,
      protocoloOutro: protocoloOutro,
      regiaoTratada: regiaoTratada.trim(),
      parametros: parametros.trim(),
      insumos: insumos,
      observacoes: observacoes.trim(),
      dataHora: DateTime.now(),
      retificaId: anterior.id,
      justificativa: justificativa,
    ));
    if (erro != null) return erro;
    _log('retificou_procedimento_estetico');
    return null;
  }

  /// Anula um registro sem substituí-lo (ele fica riscado no histórico).
  Future<String?> anular(ProcedimentoEstetico anterior, String justificativa) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.adicionarProcedimento(ProcedimentoEstetico(
      id: _repo.novoId(),
      pacienteId: _paciente.id,
      atendimentoId: anterior.atendimentoId,
      profissionalId: _usuario.id,
      protocolo: anterior.protocolo,
      dataHora: DateTime.now(),
      retificaId: anterior.id,
      justificativa: justificativa,
      anulacao: true,
    ));
    if (erro != null) return erro;
    _log('anulou_procedimento_estetico');
    return null;
  }

  @override
  Future<void> close() {
    _repo.removeListener(_aoMudarRepositorio);
    return super.close();
  }
}