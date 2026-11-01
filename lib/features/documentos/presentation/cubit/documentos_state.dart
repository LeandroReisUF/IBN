import 'package:ibn/features/documentos/domain/documentos.dart';

/// Estados da aba de Documentos de um paciente.
sealed class DocumentosState {
  const DocumentosState();
}

final class DocumentosInitial extends DocumentosState {
  const DocumentosInitial();
}

final class DocumentosLoading extends DocumentosState {
  const DocumentosLoading();
}

/// Só traz os documentos do profissional logado (RN03), do mais recente ao
/// mais antigo. [retificados]: ids de documentos corrigidos por outro.
/// [modelos]: última versão de cada modelo.
final class DocumentosSuccess extends DocumentosState {
  final List<DocumentoClinico> documentos;
  final Set<String> retificados;
  final List<ModeloDocumento> modelos;
  const DocumentosSuccess(this.documentos, this.retificados, this.modelos);
}

final class DocumentosError extends DocumentosState {
  final String mensagem;
  const DocumentosError(this.mensagem);
}