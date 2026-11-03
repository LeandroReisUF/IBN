import 'package:ibn/features/anamnese/domain/anamnese.dart';

/// Estados da aba de Anamnese de um paciente.
sealed class AnamneseState {
  const AnamneseState();
}

final class AnamneseInitial extends AnamneseState {
  const AnamneseInitial();
}

final class AnamneseLoading extends AnamneseState {
  const AnamneseLoading();
}

/// [anamneses]: só as do profissional logado (RN03), da mais recente à mais antiga.
/// [substituidas]: ids de anamneses que já têm uma versão mais nova.
/// [modelos]: os modelos que o perfil do usuário pode usar.
final class AnamneseSuccess extends AnamneseState {
  final List<Anamnese> anamneses;
  final Set<String> substituidas;
  final List<ModeloAnamnese> modelos;
  const AnamneseSuccess(this.anamneses, this.substituidas, this.modelos);
}

final class AnamneseError extends AnamneseState {
  final String mensagem;
  const AnamneseError(this.mensagem);
}