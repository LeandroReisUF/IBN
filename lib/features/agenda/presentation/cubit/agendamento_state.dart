import 'package:ibn/core/agendamento.dart';

/// Estados possíveis da agenda. `sealed` permite ao compilador avisar se
/// você esquecer de tratar algum estado num `switch`.
sealed class AgendamentoState {
  const AgendamentoState();
}

/// Ainda não carregou nada.
final class AgendamentoInitial extends AgendamentoState {
  const AgendamentoInitial();
}

/// Buscando os agendamentos.
final class AgendamentoLoading extends AgendamentoState {
  const AgendamentoLoading();
}

/// Carregou: [consultas] já vem filtrada pelo que o usuário logado pode ver (RN03).
final class AgendamentoSuccess extends AgendamentoState {
  final List<Agendamento> consultas;
  const AgendamentoSuccess(this.consultas);
}

/// Falha ao carregar a lista.
final class AgendamentoError extends AgendamentoState {
  final String mensagem;
  const AgendamentoError(this.mensagem);
}