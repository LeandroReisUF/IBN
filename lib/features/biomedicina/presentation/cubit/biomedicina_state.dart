import 'package:ibn/features/biomedicina/domain/biomedicina.dart';

/// Estados da aba de procedimentos estéticos de um paciente.
sealed class BiomedicinaState {
  const BiomedicinaState();
}

final class BiomedicinaInitial extends BiomedicinaState {
  const BiomedicinaInitial();
}

final class BiomedicinaLoading extends BiomedicinaState {
  const BiomedicinaLoading();
}

/// Só traz os registros do profissional logado (RN03), do mais recente ao mais
/// antigo. [retificados]: ids de registros corrigidos ou anulados por outro.
final class BiomedicinaSuccess extends BiomedicinaState {
  final List<ProcedimentoEstetico> procedimentos;
  final Set<String> retificados;
  const BiomedicinaSuccess(this.procedimentos, this.retificados);
}

final class BiomedicinaError extends BiomedicinaState {
  final String mensagem;
  const BiomedicinaError(this.mensagem);
}