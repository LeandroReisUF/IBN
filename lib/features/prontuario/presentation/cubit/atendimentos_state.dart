import 'package:ibn/features/prontuario/domain/prontuario.dart';

/// Uma evolução com os adendos que a corrigem (para a tela não precisar montar isso).
class EvolucaoComAdendos {
  final Evolucao evolucao;
  final List<Adendo> adendos;
  const EvolucaoComAdendos(this.evolucao, this.adendos);
}

/// Um atendimento com suas evoluções (da mais antiga para a mais nova).
class AtendimentoDetalhe {
  final Atendimento atendimento;
  final List<EvolucaoComAdendos> evolucoes;
  const AtendimentoDetalhe(this.atendimento, this.evolucoes);
}

/// Estados da aba "Atendimentos" de um paciente.
sealed class AtendimentosState {
  const AtendimentosState();
}

final class AtendimentosInitial extends AtendimentosState {
  const AtendimentosInitial();
}

final class AtendimentosLoading extends AtendimentosState {
  const AtendimentosLoading();
}

/// [atendimentos] só traz os do profissional logado, do mais recente ao mais antigo.
final class AtendimentosSuccess extends AtendimentosState {
  final List<AtendimentoDetalhe> atendimentos;
  const AtendimentosSuccess(this.atendimentos);

  /// Há um atendimento em aberto (não encerrado)?
  bool get temAtivo => atendimentos.any((d) => !d.atendimento.encerrado);
}

final class AtendimentosError extends AtendimentosState {
  final String mensagem;
  const AtendimentosError(this.mensagem);
}