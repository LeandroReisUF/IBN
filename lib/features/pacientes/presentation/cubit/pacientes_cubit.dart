import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibn/core/formadores.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/pacientes/data/paciente_repository.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'pacientes_state.dart';

/// Estado da lista de pacientes (Initial → Loading → Success | Error).
///
/// Envolve o [PacienteRepository] em memória. Outras partes do app (Agenda,
/// que vincula o paciente ao profissional) também alteram o repositório; o
/// Cubit escuta e se atualiza sozinho.
///
/// As ações repetem as permissões da [PoliticaAcessoService]. No app isso é só
/// uma segunda trava (a tela já esconde os botões); a regra de verdade tem que
/// existir no servidor.
class PacientesCubit extends Cubit<PacientesState> {
  PacientesCubit({required PacienteRepository repositorio, required Usuario usuario})
      : _repo = repositorio,
        _usuario = usuario,
        super(const PacientesInitial()) {
    _repo.addListener(_aoMudarRepositorio);
  }

  final PacienteRepository _repo;
  final Usuario _usuario;

  /// RN03: cada perfil só recebe os pacientes que pode ver.
  Future<List<Paciente>> _buscar() async =>
      politicaAcesso.filtrarPacientes(_usuario, _repo.todos);

  Future<void> carregar() async {
    emit(const PacientesLoading());
    try {
      emit(PacientesSuccess(await _buscar()));
    } catch (_) {
      emit(const PacientesError('Não foi possível carregar os pacientes.'));
    }
  }

  void _aoMudarRepositorio() {
    if (state is PacientesSuccess) _atualizarSemLoading();
  }

  Future<void> _atualizarSemLoading() async {
    try {
      final lista = await _buscar();
      if (!isClosed) emit(PacientesSuccess(lista));
    } catch (_) {
      // Mantém a lista que já estava na tela.
    }
  }

  // ---------- consultas usadas pelo formulário ----------

  bool cpfJaCadastrado(String cpfDigitos, {String? ignorarId}) =>
      _repo.cpfJaCadastrado(cpfDigitos, ignorarId: ignorarId);

  String novoId() => _repo.novoId();

  // ---------- ações ----------
  // Devolvem a mensagem de erro ou null se deu certo. Erro de regra NÃO troca
  // o estado: a lista continua na tela e a UI mostra um SnackBar.

  Future<String?> salvar(Paciente p) async {
    if (!politicaAcesso.podeEditarPaciente(_usuario)) {
      return 'Você não tem permissão para cadastrar ou editar pacientes.';
    }
    if (p.nome.trim().isEmpty) return 'Informe o nome do paciente.';
    if (!cpfValido(p.cpf)) return 'CPF inválido.';
    if (_repo.cpfJaCadastrado(p.cpf, ignorarId: p.id)) return 'CPF já cadastrado.';
    _repo.salvar(p);
    return null;
  }

  /// Inativar / reativar: o cadastro e o histórico continuam guardados (RN05).
  Future<String?> definirAtivo(String id, bool ativo) async {
    if (!politicaAcesso.podeInativarPaciente(_usuario)) {
      return 'Você não tem permissão para inativar ou reativar pacientes.';
    }
    if (_repo.buscarPorId(id) == null) return 'Paciente não encontrado.';
    _repo.definirAtivo(id, ativo);
    return null;
  }

  /// Exclusão definitiva: só Administrador e só sem nenhum histórico.
  Future<String?> excluir(String id) async {
    if (!politicaAcesso.podeExcluirPaciente(_usuario)) {
      return 'Só o Administrador pode excluir um cadastro.';
    }
    if (_repo.buscarPorId(id) == null) return 'Paciente não encontrado.';
    if (!_repo.excluirSemHistorico(id)) {
      return 'Este paciente tem histórico e não pode ser excluído. Use Inativar.';
    }
    return null;
  }

  @override
  Future<void> close() {
    _repo.removeListener(_aoMudarRepositorio);
    return super.close();
  }
}