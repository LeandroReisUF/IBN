import 'package:ibn/features/exames/domain/exames.dart';

/// Estados da aba de Exames de um paciente.
sealed class ExamesState {
  const ExamesState();
}

final class ExamesInitial extends ExamesState {
  const ExamesInitial();
}

final class ExamesLoading extends ExamesState {
  const ExamesLoading();
}

/// Só traz os exames do profissional logado (RN03), do mais recente ao mais antigo.
/// [arquivos]: arquivos de cada exame (chave = id do exame).
/// [substituidos]: ids de arquivos já substituídos por outro.
final class ExamesSuccess extends ExamesState {
  final List<Exame> exames;
  final Map<String, List<ArquivoClinico>> arquivos;
  final Set<String> substituidos;
  const ExamesSuccess(this.exames, this.arquivos, this.substituidos);
}

final class ExamesError extends ExamesState {
  final String mensagem;
  const ExamesError(this.mensagem);
}