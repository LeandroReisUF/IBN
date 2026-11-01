import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/documentos/data/documentos_repository.dart';
import 'package:ibn/features/documentos/domain/documentos.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'documentos_state.dart';

/// Documentos de UM paciente, vistos pelo profissional logado.
/// Initial → Loading → Success | Error.
///
/// As ações devolvem a mensagem de erro (ou null) e NÃO trocam o estado.
/// A trava de acesso aqui é só uma segunda camada: no servidor a regra
/// precisa ser repetida.
class DocumentosCubit extends Cubit<DocumentosState> {
  DocumentosCubit({
    required DocumentosRepository repositorio,
    required ProntuarioRepository prontuario,
    required Usuario usuario,
    required Paciente paciente,
  })  : _repo = repositorio,
        _prontuario = prontuario,
        _usuario = usuario,
        _paciente = paciente,
        super(const DocumentosInitial()) {
    _repo.addListener(_aoMudarRepositorio);
  }

  final DocumentosRepository _repo;
  final ProntuarioRepository _prontuario;
  final Usuario _usuario;
  final Paciente _paciente;

  // ---------- carregamento ----------

  Future<DocumentosSuccess> _buscar() async => DocumentosSuccess(
        _repo.documentosDoPaciente(_paciente.id, profissionalId: _usuario.id),
        _repo.retificados(_paciente.id),
        _repo.modelos,
      );

  Future<void> carregar() async {
    emit(const DocumentosLoading());
    try {
      emit(await _buscar());
    } catch (_) {
      emit(const DocumentosError('Não foi possível carregar os documentos.'));
    }
  }

  void _aoMudarRepositorio() {
    if (state is DocumentosSuccess) _atualizarSemLoading();
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

  String? _semAcesso() => politicaAcesso.podeEditarDocumentos(_usuario, _paciente)
      ? null
      : 'Você não tem permissão para emitir documentos deste paciente.';

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

  /// Valores das variáveis automáticas (paciente, data, profissional).
  Map<String, String> valoresAutomaticosAgora({DateTime? agora}) => valoresAutomaticos(
        paciente: _paciente,
        usuario: _usuario,
        agora: agora ?? DateTime.now(),
      );

  /// Só dentistas editam os modelos da clínica (provisório).
  bool get podeEditarModelos => _usuario.perfil == Perfil.dentista;

  // ---------- documentos ----------

  /// Cria um rascunho a partir do [modelo], com os valores digitados em [manuais].
  Future<String?> gerar(ModeloDocumento modelo, Map<String, String> manuais) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final atendimento = _prontuario.atendimentoAtivo(_paciente.id, _usuario.id);
    if (atendimento == null) {
      return 'Inicie um atendimento na aba Atendimentos antes de emitir o documento.';
    }
    final agora = DateTime.now();
    final r = preencherModelo(
      modelo.corpo,
      {...valoresAutomaticosAgora(agora: agora), ...manuais},
    );
    if (r.faltando.contains('profissional_registro')) {
      return 'Cadastre o registro do conselho do profissional (ex.: CRO) antes de emitir.';
    }
    if (r.faltando.isNotEmpty) return 'Preencha: ${r.faltando.join(', ')}.';

    final erro = _repo.adicionarDocumento(DocumentoClinico(
      id: _repo.novoId(),
      pacienteId: _paciente.id,
      atendimentoId: atendimento.id,
      profissionalId: _usuario.id,
      tipo: modelo.tipo,
      titulo: modelo.nome,
      conteudo: r.texto,
      modeloId: modelo.id,
      modeloVersao: modelo.versao,
      emitidoEm: agora,
    ));
    if (erro != null) return erro;
    _log('emitiu_documento');
    return null;
  }

  Future<String?> atualizarRascunho(DocumentoClinico d, String novoConteudo) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    return _repo.atualizarRascunho(d.id, _usuario.id, novoConteudo);
  }

  Future<String?> descartarRascunho(DocumentoClinico d) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    return _repo.descartarRascunho(d.id, _usuario.id);
  }

  Future<String?> assinar(DocumentoClinico d) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.assinarDocumento(d.id, _usuario.id);
    if (erro != null) return erro;
    _log('assinou_documento');
    return null;
  }

  /// Corrige um documento assinado: cria um novo rascunho que o retifica (RN05).
  Future<String?> retificar(
    DocumentoClinico anterior,
    String novoConteudo,
    String justificativa,
  ) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    final erro = _repo.adicionarDocumento(DocumentoClinico(
      id: _repo.novoId(),
      pacienteId: _paciente.id,
      atendimentoId: anterior.atendimentoId,
      profissionalId: _usuario.id,
      tipo: anterior.tipo,
      titulo: anterior.titulo,
      conteudo: novoConteudo,
      modeloId: anterior.modeloId,
      modeloVersao: anterior.modeloVersao,
      emitidoEm: DateTime.now(),
      retificaId: anterior.id,
      justificativa: justificativa,
    ));
    if (erro != null) return erro;
    _log('corrigiu_documento');
    return null;
  }

  // ---------- modelos ----------

  Future<String?> salvarModelo(ModeloDocumento m) async {
    if (!podeEditarModelos) return 'Só dentistas editam os modelos de documento.';
    final erro = _repo.salvarModelo(m);
    if (erro != null) return erro;
    _log('editou_modelo_documento');
    return null;
  }

  @override
  Future<void> close() {
    _repo.removeListener(_aoMudarRepositorio);
    return super.close();
  }
}