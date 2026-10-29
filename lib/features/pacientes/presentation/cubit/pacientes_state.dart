import 'package:ibn/features/pacientes/domain/paciente.dart';

/// Estados da lista de pacientes (mesmo padrão do AgendamentoState).
sealed class PacientesState {
  const PacientesState();
}

final class PacientesInitial extends PacientesState {
  const PacientesInitial();
}

final class PacientesLoading extends PacientesState {
  const PacientesLoading();
}

/// [pacientes] já vem filtrada pelo que o usuário logado pode ver (RN03).
/// Inclui os inativos; a tela decide se mostra.
final class PacientesSuccess extends PacientesState {
  final List<Paciente> pacientes;
  const PacientesSuccess(this.pacientes);
}

final class PacientesError extends PacientesState {
  final String mensagem;
  const PacientesError(this.mensagem);
}