/// Unidade em que a quantidade de um insumo é medida.
enum UnidadeInsumo {
  unidades('U'),
  mililitros('ml');

  final String rotulo;
  const UnidadeInsumo(this.rotulo);
}

/// Insumo controlado aplicado em um procedimento, com lote e validade (RN06).
/// Compartilhado por HOF, Biomedicina e, depois, Estoque.
class LoteAplicado {
  final String produto;
  final String? marca;
  final String lote;
  final DateTime validade; // vale até o fim desse dia
  final double quantidade;
  final UnidadeInsumo unidade;

  const LoteAplicado({
    required this.produto,
    this.marca,
    required this.lote,
    required this.validade,
    required this.quantidade,
    this.unidade = UnidadeInsumo.unidades,
  });

  /// Vencido se a validade é anterior ao dia de [data].
  bool vencidoEm(DateTime data) =>
      validade.isBefore(DateTime(data.year, data.month, data.day));

  /// Mensagem de erro (RN06), ou null se o lote pode ser usado em [data].
  String? validar(DateTime data) {
    if (produto.trim().isEmpty) return 'Informe o produto.';
    if (lote.trim().isEmpty) return 'Informe o lote do produto (RN06).';
    if (quantidade <= 0) return 'Informe a quantidade aplicada.';
    if (vencidoEm(data)) return 'O lote ${lote.trim()} está vencido (RN06).';
    return null;
  }
}