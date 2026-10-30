import 'package:ibn/features/hof/domain/hof.dart';

/// Estados da aba de Harmonização Orofacial de um paciente.
sealed class HofState {
  const HofState();
}

final class HofInitial extends HofState {
  const HofInitial();
}

final class HofLoading extends HofState {
  const HofLoading();
}

/// Só traz os registros do profissional logado (RN03).
/// [procedimentos]: do mais recente ao mais antigo; [retificados]: ids corrigidos.
final class HofSuccess extends HofState {
  final List<ProcedimentoHOF> procedimentos;
  final Set<String> retificados;
  final List<FotoComparativaHOF> fotos;
  const HofSuccess(this.procedimentos, this.retificados, this.fotos);
}

final class HofError extends HofState {
  final String mensagem;
  const HofError(this.mensagem);
}