/// Faces do dente (RF04.1).
enum FaceDente {
  vestibular('Vestibular'),
  lingual('Lingual/Palatina'),
  mesial('Mesial'),
  distal('Distal'),
  oclusal('Oclusal/Incisal');

  final String rotulo;
  const FaceDente(this.rotulo);
}

/// Situação registrada para um dente ou uma face.
enum SituacaoDente {
  existente('Existente'),
  realizado('Realizado'),
  planejado('Planejado'),
  ausente('Ausente');

  final String rotulo;
  const SituacaoDente(this.rotulo);
}

/// Numeração FDI (dentição permanente). Ordem de desenho: da direita para a
/// esquerda do paciente, como no odontograma impresso.
const List<int> dentesSuperiores = [18, 17, 16, 15, 14, 13, 12, 11, 21, 22, 23, 24, 25, 26, 27, 28];
const List<int> dentesInferiores = [48, 47, 46, 45, 44, 43, 42, 41, 31, 32, 33, 34, 35, 36, 37, 38];

/// Um registro no histórico do odontograma. Registros nunca são apagados
/// nem alterados: o estado atual é sempre o último registro (rastreabilidade).
class RegistroDente {
  final String id;
  final String pacienteId;
  final int numeroDente;
  final FaceDente? face; // null = dente inteiro
  final SituacaoDente situacao;
  final String? procedimentoId;
  final String observacao;
  final DateTime data;
  final String profissionalId; // pessoa que registrou

  const RegistroDente({
    required this.id,
    required this.pacienteId,
    required this.numeroDente,
    this.face,
    required this.situacao,
    this.procedimentoId,
    this.observacao = '',
    required this.data,
    required this.profissionalId,
  });

  /// Chave usada para guardar o estado atual: "16-oclusal" ou "36-dente".
  static String chave(int dente, FaceDente? face) {
    final sufixo = face == null ? 'dente' : face.name;
    return '$dente-$sufixo';
  }
}