import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/anamnese/data/anamnese_repository.dart';
import 'package:ibn/features/anamnese/domain/anamnese.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'anamnese_state.dart';

/// Anamneses de UM paciente, vistas pelo profissional logado.
/// Initial → Loading → Success | Error.
///
/// As ações devolvem a mensagem de erro (ou null) e NÃO trocam o estado.
/// A trava de acesso aqui é só uma segunda camada: no servidor a regra
/// precisa ser repetida.
class AnamneseCubit extends Cubit<AnamneseState> {
  AnamneseCubit({
    required AnamneseRepository repositorio,
    required ProntuarioRepository prontuario,
    required Usuario usuario,
    required Paciente paciente,
  })  : _repo = repositorio,
        _prontuario = prontuario,
        _usuario = usuario,
        _paciente = paciente,
        super(const AnamneseInitial()) {
    _repo.addListener(_aoMudarRepositorio);
  }

  final AnamneseRepository _repo;
  final ProntuarioRepository _prontuario;
  final Usuario _usuario;
  final Paciente _paciente;

  // ---------- carregamento ----------

  /// Modelos do perfil: os da sua especialidade e os gerais.
  List<ModeloAnamnese> get modelosDoUsuario => [
        for (final m in _repo.modelos)
          if (m.especialidade == null || _usuario.perfil.especialidades.contains(m.especialidade))
            m,
      ];

    Future<AnamneseSuccess> _buscar() async => AnamneseSuccess(
        _repo.anamnesesVisiveis(
          _paciente.id,
          profissionalId: _usuario.id,
          especialidades: _usuario.perfil.especialidades,
        ),
        _repo.substituidas(_paciente.id),
        modelosDoUsuario,
      );

  Future<void> carregar() async {
    emit(const AnamneseLoading());
    try {
      emit(await _buscar());
    } catch (_) {
      emit(const AnamneseError('Não foi possível carregar as anamneses.'));
    }
  }

  void _aoMudarRepositorio() {
    if (state is AnamneseSuccess) _atualizarSemLoading();
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

  String? _semAcesso() => politicaAcesso.podeEditarAnamnese(_usuario, _paciente)
      ? null
      : 'Você não tem permissão para registrar anamnese deste paciente.';

  void _log(String acao) {
    logsAcesso.registrar(
      usuarioId: _usuario.id,
      acao: acao,
      entidade: 'paciente',
      entidadeId: _paciente.id,
    );
  }

  String? _incompleta(List<PerguntaAnamnese> perguntas, Map<String, String> respostas) {
    final faltando = faltandoObrigatorias(perguntas, respostas);
    return faltando.isEmpty ? null : 'Responda: ${faltando.join('; ')}.';
  }

  // ---------- anamnese ----------

  /// Salva uma anamnese nova como rascunho; com [assinar], já a assina (todas
  /// as obrigatórias precisam estar respondidas). [anterior] = a assinada que
  /// esta versão atualiza.
  Future<String?> salvar(
    ModeloAnamnese modelo,
    Map<String, String> respostas, {
    Anamnese? anterior,
    bool assinar = false,
  }) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    if (assinar) {
      final incompleta = _incompleta(modelo.perguntas, respostas);
      if (incompleta != null) return incompleta;
    }
    final a = Anamnese(
      id: _repo.novoId(),
      pacienteId: _paciente.id,
      atendimentoId: _prontuario.atendimentoAtivo(_paciente.id, _usuario.id)?.id,
      profissionalId: _usuario.id,
      modeloId: modelo.id,
      titulo: modelo.nome,
      modeloVersao: modelo.versao,
      perguntas: modelo.perguntas,
      respostas: Map.of(respostas),
      criadaEm: DateTime.now(),
      anteriorId: anterior?.id,
    );
    var erro = _repo.adicionarAnamnese(a);
    if (erro != null) return erro;
    _log(anterior == null ? 'registrou_anamnese' : 'atualizou_anamnese');
    if (assinar) {
      erro = _repo.assinarAnamnese(a.id, _usuario.id);
      if (erro != null) return erro;
      _log('assinou_anamnese');
    }
    return null;
  }

  /// Atualiza as respostas de um rascunho; com [assinar], também o assina.
  Future<String?> atualizarRascunho(
    Anamnese a,
    Map<String, String> respostas, {
    bool assinar = false,
  }) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    if (assinar) {
      final incompleta = _incompleta(a.perguntas, respostas);
      if (incompleta != null) return incompleta;
    }
    var erro = _repo.atualizarRascunho(a.id, _usuario.id, respostas);
    if (erro != null) return erro;
    if (assinar) {
      erro = _repo.assinarAnamnese(a.id, _usuario.id);
      if (erro != null) return erro;
      _log('assinou_anamnese');
    }
    return null;
  }

  Future<String?> descartarRascunho(Anamnese a) async {
    final sem = _semAcesso();
    if (sem != null) return sem;
    return _repo.descartarRascunho(a.id, _usuario.id);
  }

  @override
  Future<void> close() {
    _repo.removeListener(_aoMudarRepositorio);
    return super.close();
  }
}