import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/exames/data/exames_repository.dart';
import 'package:ibn/features/exames/domain/exames.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'exames_state.dart';

/// Exames de UM paciente, vistos pelo profissional logado.
/// Initial → Loading → Success | Error.
///
/// As ações devolvem a mensagem de erro (ou null) e NÃO trocam o estado.
/// A trava de acesso aqui é só uma segunda camada: no servidor a regra
/// precisa ser repetida.
class ExamesCubit extends Cubit<ExamesState> {
  ExamesCubit({
    required ExamesRepository repositorio,
    required ProntuarioRepository prontuario,
    required Usuario usuario,
    required Paciente paciente,
  })  : _repo = repositorio,
        _prontuario = prontuario,
        _usuario = usuario,
        _paciente = paciente,
        super(const ExamesInitial()) {
    _repo.addListener(_aoMudarRepositorio);
  }

  final ExamesRepository _repo;
  final ProntuarioRepository _prontuario;
  final Usuario _usuario;
  final Paciente _paciente;

  // ---------- carregamento ----------

  Future<ExamesSuccess> _buscar() async {
    final exames = _repo.examesDoPaciente(_paciente.id, profissionalId: _usuario.id);
    return ExamesSuccess(
      exames,
      {for (final e in exames) e.id: _repo.arquivosDoExame(e.id)},
      _repo.arquivosRetificados(_paciente.id),
    );
  }

  Future<void> carregar() async {
    emit(const ExamesLoading());
    try {
      emit(await _buscar());
    } catch (_) {
      emit(const ExamesError('Não foi possível carregar os exames.'));
    }
  }

  void _aoMudarRepositorio() {
    if (state is ExamesSuccess) _atualizarSemLoading();
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

  String? _semAcesso() => politicaAcesso.podeEditarExames(_usuario, _paciente)
      ? null
      : 'Você não tem permissão para gerenciar exames deste paciente.';

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

  // ---------- exames ----------

  Future<String?> solicitar({
    required TipoExame tipo,
    required String nome,
    String? descricao,
  }) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final atendimento = _prontuario.atendimentoAtivo(_paciente.id, _usuario.id);
    if (atendimento == null) {
      return 'Inicie um atendimento na aba Atendimentos antes de solicitar o exame.';
    }
    final agora = DateTime.now();
    final erro = _repo.solicitarExame(Exame(
      id: _repo.novoId(),
      pacienteId: _paciente.id,
      atendimentoId: atendimento.id,
      profissionalId: _usuario.id,
      tipo: tipo,
      nome: nome,
      descricao: descricao,
      solicitadoEm: agora,
      atualizadoEm: agora,
    ));
    if (erro != null) return erro;
    _log('solicitou_exame');
    return null;
  }

  Future<String?> mudarStatus(Exame e, StatusExame novo) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.mudarStatus(e.id, _usuario.id, novo);
    if (erro != null) return erro;
    _log('mudou_status_exame');
    return null;
  }

  // ---------- arquivos ----------

  Future<String?> anexar(Exame e, {required String nomeArquivo, required Uint8List bytes}) =>
      _incluir(e, nomeArquivo, bytes);

  /// Substitui um arquivo: o anterior fica riscado, nada é apagado (RN05).
  Future<String?> substituir(
    Exame e,
    ArquivoClinico anterior, {
    required String nomeArquivo,
    required Uint8List bytes,
    required String justificativa,
  }) =>
      _incluir(e, nomeArquivo, bytes, anterior: anterior, justificativa: justificativa);

  Future<String?> _incluir(
    Exame e,
    String nomeArquivo,
    Uint8List bytes, {
    ArquivoClinico? anterior,
    String? justificativa,
  }) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final mime = mimeDoArquivo(nomeArquivo);
    if (mime == null) return 'Formato não permitido. Use JPG, PNG ou PDF.';
    final erro = _repo.adicionarArquivo(ArquivoClinico(
      id: _repo.novoId(),
      exameId: e.id,
      pacienteId: _paciente.id,
      nomeArquivo: nomeArquivo,
      mimeType: mime,
      bytes: bytes,
      enviadoEm: DateTime.now(),
      profissionalId: _usuario.id,
      retificaId: anterior?.id,
      justificativa: justificativa,
    ));
    if (erro != null) return erro;
    _log(anterior == null ? 'anexou_arquivo_exame' : 'substituiu_arquivo_exame');
    return null;
  }

  @override
  Future<void> close() {
    _repo.removeListener(_aoMudarRepositorio);
    return super.close();
  }
}