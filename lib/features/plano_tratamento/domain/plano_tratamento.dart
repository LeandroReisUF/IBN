/// Plano de tratamento e orçamento (RF04.5, RN04). Modelos imutáveis.
/// Valores em CENTAVOS (inteiros), para não somar dinheiro com `double`.
///
/// RN04: quem EXECUTA um procedimento encaminhado recebe só a
/// [GuiaProcedimentoExecutante], que não tem nenhum campo de dinheiro.
/// Valores, descontos e pagamento ficam com o criador do plano e o Administrador.

enum StatusItem {
  planejado('Planejado'),
  encaminhado('Encaminhado'),
  realizado('Realizado'),
  cancelado('Cancelado');

  final String rotulo;
  const StatusItem(this.rotulo);
}

enum FormaPagamento {
  pix('PIX'),
  cartaoCredito('Cartão de crédito'),
  cartaoDebito('Cartão de débito'),
  dinheiro('Dinheiro'),
  boleto('Boleto');

  final String rotulo;
  const FormaPagamento(this.rotulo);
}

/// Um procedimento do plano. Nunca é apagado: se não será feito, fica "Cancelado".
class ItemPlano {
  final String id;
  final String procedimentoId;
  final int? dente; // número FDI, se o procedimento é em um dente
  final String instrucoes; // instruções CLÍNICAS (aparecem na guia)
  final int valorCentavos;
  final int descontoCentavos;
  final StatusItem status;
  final String? executanteId; // null = o próprio criador executa
  final DateTime? encaminhadoEm;
  final DateTime? realizadoEm;
  final String? realizadoPorId;

  const ItemPlano({
    required this.id,
    required this.procedimentoId,
    this.dente,
    this.instrucoes = '',
    required this.valorCentavos,
    this.descontoCentavos = 0,
    this.status = StatusItem.planejado,
    this.executanteId,
    this.encaminhadoEm,
    this.realizadoEm,
    this.realizadoPorId,
  });

  int get liquidoCentavos => valorCentavos - descontoCentavos;

  ItemPlano copiarCom({
    String? instrucoes,
    StatusItem? status,
    String? executanteId,
    DateTime? encaminhadoEm,
    DateTime? realizadoEm,
    String? realizadoPorId,
  }) =>
      ItemPlano(
        id: id,
        procedimentoId: procedimentoId,
        dente: dente,
        instrucoes: instrucoes ?? this.instrucoes,
        valorCentavos: valorCentavos,
        descontoCentavos: descontoCentavos,
        status: status ?? this.status,
        executanteId: executanteId ?? this.executanteId,
        encaminhadoEm: encaminhadoEm ?? this.encaminhadoEm,
        realizadoEm: realizadoEm ?? this.realizadoEm,
        realizadoPorId: realizadoPorId ?? this.realizadoPorId,
      );
}

class Orcamento {
  final FormaPagamento forma;
  final int parcelas;
  const Orcamento({required this.forma, this.parcelas = 1});
}

class PlanoTratamento {
  final String id;
  final String pacienteId;
  final String criadorId;
  final String titulo;
  final DateTime criadoEm;
  final List<ItemPlano> itens;
  final Orcamento? orcamento;

  const PlanoTratamento({
    required this.id,
    required this.pacienteId,
    required this.criadorId,
    required this.titulo,
    required this.criadoEm,
    this.itens = const [],
    this.orcamento,
  });

  /// Itens que ainda contam no orçamento (os cancelados ficam de fora).
  Iterable<ItemPlano> get itensAtivos => itens.where((i) => i.status != StatusItem.cancelado);

  int get totalBrutoCentavos => itensAtivos.fold(0, (s, i) => s + i.valorCentavos);
  int get descontoTotalCentavos => itensAtivos.fold(0, (s, i) => s + i.descontoCentavos);
  int get totalNegociadoCentavos => totalBrutoCentavos - descontoTotalCentavos;

  /// Valor de cada parcela (a última absorve a diferença do arredondamento).
  int get parcelaCentavos {
    final n = orcamento?.parcelas ?? 1;
    return totalNegociadoCentavos ~/ n;
  }

  PlanoTratamento copiarCom({List<ItemPlano>? itens, Orcamento? orcamento}) => PlanoTratamento(
        id: id,
        pacienteId: pacienteId,
        criadorId: criadorId,
        titulo: titulo,
        criadoEm: criadoEm,
        itens: itens ?? this.itens,
        orcamento: orcamento ?? this.orcamento,
      );
}

/// O que o executante vê: procedimento, dente e instruções clínicas.
/// **Não tem nenhum campo de dinheiro** (valor, desconto, total, pagamento): a
/// garantia vem da forma dos dados (RN04).
class GuiaProcedimentoExecutante {
  final String planoId;
  final String itemId;
  final String pacienteId;
  final String procedimentoId;
  final int? dente;
  final String instrucoes;
  final StatusItem status;
  final String executanteId;
  final DateTime? encaminhadoEm;
  final DateTime? realizadoEm;

  const GuiaProcedimentoExecutante({
    required this.planoId,
    required this.itemId,
    required this.pacienteId,
    required this.procedimentoId,
    required this.dente,
    required this.instrucoes,
    required this.status,
    required this.executanteId,
    required this.encaminhadoEm,
    required this.realizadoEm,
  });

  /// TODOS os campos da guia. Os testes varrem este mapa em busca de dinheiro.
  Map<String, Object?> paraMapa() => {
        'planoId': planoId,
        'itemId': itemId,
        'pacienteId': pacienteId,
        'procedimentoId': procedimentoId,
        'dente': dente,
        'instrucoes': instrucoes,
        'status': status.name,
        'executanteId': executanteId,
        'encaminhadoEm': encaminhadoEm?.toIso8601String(),
        'realizadoEm': realizadoEm?.toIso8601String(),
      };
}

// ---------- dinheiro ----------

/// Ex.: 150050 → "R$ 1.500,50".
String formatarReais(int centavos) {
  final negativo = centavos < 0;
  final c = centavos.abs();
  final reais = (c ~/ 100)
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  final cent = (c % 100).toString().padLeft(2, '0');
  return '${negativo ? '-' : ''}R\$ $reais,$cent';
}

/// Lê "1.500,50", "1500,5" ou "150.5" em centavos; null se inválido ou negativo.
int? lerCentavos(String texto) {
  var s = texto.trim();
  if (s.isEmpty) return null;
  if (s.contains(',')) s = s.replaceAll('.', '').replaceAll(',', '.');
  final v = double.tryParse(s);
  if (v == null || v < 0) return null;
  return (v * 100).round();
}