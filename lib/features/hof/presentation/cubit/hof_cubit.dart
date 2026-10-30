import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/core/lote_aplicado.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/hof/data/hof_repository.dart';
import 'package:ibn/features/hof/domain/hof.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'hof_state.dart';

/// HOF de UM paciente, visto pelo profissional logado.
/// Initial → Loading → Success | Error.
///
/// As ações devolvem a mensagem de erro (ou null) e NÃO trocam o estado.
/// A trava de acesso aqui é só uma segunda camada: no servidor a regra
/// precisa ser repetida.
class HofCubit extends Cubit<HofState> {
  HofCubit({
    required HofRepository repositorio,
    required ProntuarioRepository prontuario,
    required Usuario usuario,
    required Paciente paciente,
  })  : _repo = repositorio,
        _prontuario = prontuario,
        _usuario = usuario,
        _paciente = paciente,
        super(const HofInitial()) {
    _repo.addListener(_aoMudarRepositorio);
  }

  final HofRepository _repo;
  final ProntuarioRepository _prontuario;
  final Usuario _usuario;
  final Paciente _paciente;

  // ---------- carregamento ----------

  Future<HofSuccess> _buscar() async => HofSuccess(
        _repo.procedimentosDoPaciente(_paciente.id, profissionalId: _usuario.id),
        _repo.retificados(_paciente.id),
        _repo.fotosDoPaciente(_paciente.id, profissionalId: _usuario.id),
      );

  Future<void> carregar() async {
    emit(const HofLoading());
    try {
      emit(await _buscar());
    } catch (_) {
      emit(const HofError('Não foi possível carregar a harmonização orofacial.'));
    }
  }

  void _aoMudarRepositorio() {
    if (state is HofSuccess) _atualizarSemLoading();
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

  String? _semAcesso() => politicaAcesso.podeEditarHof(_usuario, _paciente)
      ? null
      : 'Você não tem permissão para registrar harmonização orofacial neste paciente.';

  void _log(String acao) {
    logsAcesso.registrar(
      usuarioId: _usuario.id,
      acao: acao,
      entidade: 'paciente',
      entidadeId: _paciente.id,
    );
  }

  /// Há atendimento em aberto deste profissional com este paciente?
  bool get temAtendimentoAberto =>
      _prontuario.atendimentoAtivo(_paciente.id, _usuario.id) != null;

  // ---------- procedimentos ----------

  Future<String?> registrar({
    required TipoHOF tipo,
    String? tipoOutro,
    required List<PontoAplicacao> pontos,
    required List<LoteAplicado> insumos,
    String? tecnica,
    String observacoes = '',
  }) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final atendimento = _prontuario.atendimentoAtivo(_paciente.id, _usuario.id);
    if (atendimento == null) {
      return 'Inicie um atendimento na aba Atendimentos antes de registrar o procedimento.';
    }
    final erro = _repo.adicionarProcedimento(ProcedimentoHOF(
      id: _repo.novoId(),
      pacienteId: _paciente.id,
      atendimentoId: atendimento.id,
      profissionalId: _usuario.id,
      tipo: tipo,
      tipoOutro: tipoOutro,
      pontos: pontos,
      insumos: insumos,
      tecnica: tecnica,
      observacoes: observacoes,
      dataHora: DateTime.now(),
    ));
    if (erro != null) return erro;
    _log('registrou_hof');
    return null;
  }

  /// Corrige um registro: o anterior fica riscado e este passa a valer (RN05).
  Future<String?> retificar(
    ProcedimentoHOF anterior, {
    required TipoHOF tipo,
    String? tipoOutro,
    required List<PontoAplicacao> pontos,
    required List<LoteAplicado> insumos,
    String? tecnica,
    String observacoes = '',
    required String justificativa,
  }) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.adicionarProcedimento(ProcedimentoHOF(
      id: _repo.novoId(),
      pacienteId: _paciente.id,
      atendimentoId: anterior.atendimentoId,
      profissionalId: _usuario.id,
      tipo: tipo,
      tipoOutro: tipoOutro,
      pontos: pontos,
      insumos: insumos,
      tecnica: tecnica,
      observacoes: observacoes,
      dataHora: DateTime.now(),
      retificaId: anterior.id,
      justificativa: justificativa,
    ));
    if (erro != null) return erro;
    _log('retificou_hof');
    return null;
  }

  /// Anula um registro sem substituí-lo (ele fica riscado no histórico).
  Future<String?> anular(ProcedimentoHOF anterior, String justificativa) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.adicionarProcedimento(ProcedimentoHOF(
      id: _repo.novoId(),
      pacienteId: _paciente.id,
      atendimentoId: anterior.atendimentoId,
      profissionalId: _usuario.id,
      tipo: anterior.tipo,
      dataHora: DateTime.now(),
      retificaId: anterior.id,
      justificativa: justificativa,
      anulacao: true,
    ));
    if (erro != null) return erro;
    _log('anulou_hof');
    return null;
  }

  // ---------- fotos ----------

  Future<String?> adicionarFoto({
    required String descricao,
    required bool isAntes,
    required String nomeArquivo,
    required Uint8List bytes,
  }) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.adicionarFoto(FotoComparativaHOF(
      id: _repo.novoId(),
      pacienteId: _paciente.id,
      data: DateTime.now(),
      descricao: descricao,
      nomeArquivo: nomeArquivo,
      bytes: bytes,
      isAntes: isAntes,
      profissionalId: _usuario.id,
    ));
    if (erro != null) return erro;
    _log('adicionou_foto_hof');
    return null;
  }

  @override
  Future<void> close() {
    _repo.removeListener(_aoMudarRepositorio);
    return super.close();
  }
}