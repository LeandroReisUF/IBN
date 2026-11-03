import 'package:ibn/features/plano_tratamento/domain/plano_tratamento.dart';

/// Estados da aba "Plano de tratamento" de um paciente.
sealed class PlanoState {
  const PlanoState();
}

final class PlanoInitial extends PlanoState {
  const PlanoInitial();
}

final class PlanoLoading extends PlanoState {
  const PlanoLoading();
}

/// RN04: [planos] (com valores) só traz os planos CRIADOS pelo usuário logado;
/// para quem só executa, vem vazio. [guias] são os procedimentos encaminhados
/// ao usuário, **sem nenhum campo de dinheiro**.
final class PlanoSuccess extends PlanoState {
  final List<PlanoTratamento> planos;
  final List<GuiaProcedimentoExecutante> guias;
  const PlanoSuccess(this.planos, this.guias);
}

final class PlanoError extends PlanoState {
  final String mensagem;
  const PlanoError(this.mensagem);
}