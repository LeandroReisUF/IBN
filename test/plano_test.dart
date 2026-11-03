import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/plano_tratamento/data/plano_repository.dart';
import 'package:ibn/features/plano_tratamento/domain/orcamento_visibilidade.dart';
import 'package:ibn/features/plano_tratamento/domain/plano_tratamento.dart';

const davi = Usuario(id: '3', nome: 'Dr. Davi', email: 'd@x', perfil: Perfil.dentista);
const lucia = Usuario(id: '10', nome: 'Dra. Lúcia', email: 'l@x', perfil: Perfil.dentista);
const admin = Usuario(id: '1', nome: 'Ana', email: 'a@x', perfil: Perfil.administrador);
const recepcao = Usuario(id: '2', nome: 'Rita', email: 'r@x', perfil: Perfil.recepcionista);

PlanoTratamento plano({String id = 'pl1', String titulo = 'Reabilitação', String criador = '3'}) =>
    PlanoTratamento(
      id: id,
      pacienteId: 'p1',
      criadorId: criador,
      titulo: titulo,
      criadoEm: DateTime(2030, 1, 7),
    );

ItemPlano item({
  String id = 'i1',
  String proc = 'restauracao',
  int? dente = 26,
  int valor = 98765, // R$ 987,65: valor "estranho" para varrer a guia
  int desconto = 1234,
  String instrucoes = 'Resina A2, isolamento absoluto',
  StatusItem status = StatusItem.planejado,
  String? executante,
}) =>
    ItemPlano(
      id: id,
      procedimentoId: proc,
      dente: dente,
      instrucoes: instrucoes,
      valorCentavos: valor,
      descontoCentavos: desconto,
      status: status,
      executanteId: executante,
    );

/// Repositório com o plano pl1 (criado pelo Dr. Davi, id 3) e o item i1.
PlanoRepository comPlano({bool comItem = true}) {
  final r = PlanoRepository();
  expect(r.criarPlano(plano()), isNull);
  if (comItem) expect(r.adicionarItem('pl1', '3', item()), isNull);
  return r;
}

void main() {
  group('Dinheiro', () {
    test('formatarReais', () {
      expect(formatarReais(0), 'R\$ 0,00');
      expect(formatarReais(5), 'R\$ 0,05');
      expect(formatarReais(98765), 'R\$ 987,65');
      expect(formatarReais(150050), 'R\$ 1.500,50');
      expect(formatarReais(123456789), 'R\$ 1.234.567,89');
      expect(formatarReais(-250), '-R\$ 2,50');
    });

    test('lerCentavos entende vírgula, milhar e ponto decimal', () {
      expect(lerCentavos('150'), 15000);
      expect(lerCentavos('150,5'), 15050);
      expect(lerCentavos('1.500,50'), 150050);
      expect(lerCentavos('150.5'), 15050);
      expect(lerCentavos(' 0,10 '), 10);
      expect(lerCentavos(''), isNull);
      expect(lerCentavos('abc'), isNull);
      expect(lerCentavos('-5'), isNull);
    });
  });

  group('Plano e itens', () {
    test('cria plano vazio e recusa título vazio, duplicado ou já com itens', () {
      final r = PlanoRepository();
      expect(r.criarPlano(plano(titulo: ' ')), contains('título'));
      expect(r.criarPlano(plano().copiarCom(itens: [item()])), contains('sem procedimentos'));
      expect(r.criarPlano(plano()), isNull);
      expect(r.criarPlano(plano()), contains('duplicado'));
      expect(r.temHistorico('p1'), isTrue);
      expect(r.temHistorico('p2'), isFalse);
    });

    test('adiciona itens e soma os totais sem os cancelados', () {
      final r = comPlano();
      r.adicionarItem('pl1', '3', item(id: 'i2', valor: 50000, desconto: 0));
      r.adicionarItem('pl1', '3', item(id: 'i3', valor: 30000, desconto: 5000));
      var p = r.planoPorId('pl1')!;
      expect(p.totalBrutoCentavos, 98765 + 50000 + 30000);
      expect(p.descontoTotalCentavos, 1234 + 5000);
      expect(p.totalNegociadoCentavos, 98765 + 50000 + 30000 - 1234 - 5000);

      expect(r.cancelarItem('pl1', 'i3', '3'), isNull);
      p = r.planoPorId('pl1')!;
      expect(p.itens.length, 3); // nada é apagado
      expect(p.totalBrutoCentavos, 98765 + 50000);
      expect(p.totalNegociadoCentavos, 98765 + 50000 - 1234);
    });

    test('valida procedimento, dente, valor e desconto', () {
      final r = comPlano(comItem: false);
      expect(r.adicionarItem('pl1', '3', item(proc: 'nao-existe')), contains('não encontrado'));
      expect(r.adicionarItem('pl1', '3', item(dente: 19)), contains('inválido'));
      expect(r.adicionarItem('pl1', '3', item(valor: -1, desconto: 0)), contains('negativo'));
      expect(r.adicionarItem('pl1', '3', item(valor: 1000, desconto: 1001)), contains('desconto'));
      expect(r.adicionarItem('pl1', '3', item(desconto: -5)), contains('desconto'));
      expect(r.adicionarItem('pl1', '3', item(status: StatusItem.realizado)), contains('Planejado'));
      expect(r.adicionarItem('pl1', '3', item(executante: '10')), contains('sem executante'));
      expect(r.adicionarItem('pl1', '3', item(dente: null)), isNull);
      expect(r.adicionarItem('pl1', '3', item(dente: null)), contains('duplicado'));
    });

    test('só o criador altera o plano', () {
      final r = comPlano();
      expect(r.adicionarItem('pl1', '10', item(id: 'i9')), contains('Só quem criou'));
      expect(r.cancelarItem('pl1', 'i1', '10'), contains('Só quem criou'));
      expect(r.definirOrcamento('pl1', '10', const Orcamento(forma: FormaPagamento.pix)),
          contains('Só quem criou'));
      expect(r.adicionarItem('zzz', '3', item(id: 'i9')), contains('não encontrado'));
    });

    test('orçamento: parcelas de 1 a 12 e só cartão de crédito ou boleto parcelam', () {
      final r = comPlano();
      expect(r.definirOrcamento('pl1', '3', const Orcamento(forma: FormaPagamento.pix, parcelas: 0)),
          contains('parcelas'));
      expect(r.definirOrcamento('pl1', '3', const Orcamento(forma: FormaPagamento.cartaoCredito, parcelas: 13)),
          contains('parcelas'));
      expect(r.definirOrcamento('pl1', '3', const Orcamento(forma: FormaPagamento.pix, parcelas: 3)),
          contains('parcelados'));
      expect(
          r.definirOrcamento('pl1', '3', const Orcamento(forma: FormaPagamento.cartaoCredito, parcelas: 4)),
          isNull);
      final p = r.planoPorId('pl1')!;
      expect(p.orcamento!.parcelas, 4);
      expect(p.parcelaCentavos, (98765 - 1234) ~/ 4);
    });

    test('cancelar: não cancela realizado nem duas vezes', () {
      final r = comPlano();
      expect(r.cancelarItem('pl1', 'zzz', '3'), contains('não encontrado'));
      r.realizarItem('pl1', 'i1', '3');
      expect(r.cancelarItem('pl1', 'i1', '3'), contains('realizado'));
      r.adicionarItem('pl1', '3', item(id: 'i2'));
      expect(r.cancelarItem('pl1', 'i2', '3'), isNull);
      expect(r.cancelarItem('pl1', 'i2', '3'), contains('já está cancelado'));
    });

    test('planosDoPaciente filtra por criador e avisa os ouvintes', () {
      final r = PlanoRepository();
      var chamadas = 0;
      r.addListener(() => chamadas++);
      r.criarPlano(plano());
      r.criarPlano(plano(id: 'pl2', criador: '10'));
      r.adicionarItem('pl1', '3', item());
      r.adicionarItem('pl1', '3', item(valor: -1)); // erro: não notifica
      expect(chamadas, 3);
      expect(r.planosDoPaciente('p1').map((p) => p.id), ['pl2', 'pl1']);
      expect(r.planosDoPaciente('p1', criadorId: '3').map((p) => p.id), ['pl1']);
      expect(r.planosDoPaciente('p1', criadorId: '10').map((p) => p.id), ['pl2']);
    });
  });

  group('Encaminhamento e execução', () {
    test('encaminhar: só o criador, só item planejado, não para si mesmo', () {
      final r = comPlano();
      expect(r.encaminharItem('pl1', 'i1', '10', '10'), contains('Só quem criou'));
      expect(r.encaminharItem('pl1', 'i1', '3', '3'), contains('você mesmo'));
      expect(r.encaminharItem('pl1', 'zzz', '3', '10'), contains('não encontrado'));
      expect(r.encaminharItem('pl1', 'i1', '3', '10', instrucoes: ' Usar resina A3 '), isNull);
      final i = r.planoPorId('pl1')!.itens.single;
      expect(i.status, StatusItem.encaminhado);
      expect(i.executanteId, '10');
      expect(i.instrucoes, 'Usar resina A3');
      expect(i.encaminhadoEm, isNotNull);
      expect(r.encaminharItem('pl1', 'i1', '3', '10'), contains('Planejado'));
    });

    test('encaminhar sem texto novo mantém as instruções', () {
      final r = comPlano();
      r.encaminharItem('pl1', 'i1', '3', '10', instrucoes: '  ');
      expect(r.planoPorId('pl1')!.itens.single.instrucoes, 'Resina A2, isolamento absoluto');
    });

    test('item não encaminhado: só o criador realiza', () {
      final r = comPlano();
      expect(r.realizarItem('pl1', 'i1', '10'), contains('Só quem criou'));
      expect(r.realizarItem('pl1', 'i1', '3', agora: DateTime(2030, 1, 8)), isNull);
      final i = r.planoPorId('pl1')!.itens.single;
      expect(i.status, StatusItem.realizado);
      expect(i.realizadoEm, DateTime(2030, 1, 8));
      expect(i.realizadoPorId, '3');
      expect(r.realizarItem('pl1', 'i1', '3'), contains('já foi realizado'));
    });

    test('item encaminhado: só o executante realiza (nem o criador)', () {
      final r = comPlano();
      r.encaminharItem('pl1', 'i1', '3', '10');
      expect(r.realizarItem('pl1', 'i1', '3'), contains('recebeu o encaminhamento'));
      expect(r.realizarItem('pl1', 'i1', '99'), contains('recebeu o encaminhamento'));
      expect(r.realizarItem('pl1', 'i1', '10'), isNull);
      expect(r.planoPorId('pl1')!.itens.single.realizadoPorId, '10');
    });

    test('item cancelado não é realizado', () {
      final r = comPlano();
      r.cancelarItem('pl1', 'i1', '3');
      expect(r.realizarItem('pl1', 'i1', '3'), contains('cancelado'));
    });
  });

  group('RN04: o executante nunca recebe valores', () {
    test('guias só dos itens encaminhados ao executante', () {
      final r = comPlano();
      r.adicionarItem('pl1', '3', item(id: 'i2'));
      r.adicionarItem('pl1', '3', item(id: 'i3'));
      expect(r.guiasDoExecutante('p1', '10'), isEmpty);
      r.encaminharItem('pl1', 'i1', '3', '10');
      r.encaminharItem('pl1', 'i2', '3', '99');
      expect(r.guiasDoExecutante('p1', '10').map((g) => g.itemId), ['i1']);
      expect(r.guiasDoExecutante('p1', '3'), isEmpty);
      expect(r.guiasDoExecutante('p2', '10'), isEmpty);
      r.realizarItem('pl1', 'i1', '10');
      expect(r.guiasDoExecutante('p1', '10').single.status, StatusItem.realizado);
      r.cancelarItem('pl1', 'i3', '3');
      expect(r.guiasDoExecutante('p1', '10').length, 1);
    });

    test('a guia não tem nenhum campo de dinheiro', () {
      final r = comPlano();
      r.definirOrcamento('pl1', '3', const Orcamento(forma: FormaPagamento.cartaoCredito, parcelas: 6));
      r.encaminharItem('pl1', 'i1', '3', '10', agora: DateTime(2030, 1, 7, 9));
      final guia = r.guiasDoExecutante('p1', '10').single;
      final mapa = guia.paraMapa();

      for (final proibida in [
        'valor', 'valorCentavos', 'desconto', 'descontoCentavos', 'total', 'liquido',
        'orcamento', 'forma', 'formaPagamento', 'parcelas', 'pagamento', 'preco',
      ]) {
        expect(mapa.containsKey(proibida), isFalse, reason: proibida);
      }
      final texto = '$mapa'.toLowerCase();
      for (final trecho in ['valor', 'desconto', 'total', 'pagamento', 'parcela', 'r\$']) {
        expect(texto.contains(trecho), isFalse, reason: trecho);
      }
      // Nenhum número do orçamento aparece nos valores da guia.
      for (final numero in ['98765', '1234', '97531', '987,65']) {
        expect('${mapa.values}'.contains(numero), isFalse, reason: numero);
      }
      expect(guia.instrucoes, 'Resina A2, isolamento absoluto');
      expect(guia.dente, 26);
    });

    test('podeVerValores: só o criador e o Administrador', () {
      final p = plano();
      expect(orcamentoVisibilidade.podeVerValores(davi, p), isTrue);
      expect(orcamentoVisibilidade.podeVerValores(admin, p), isTrue);
      expect(orcamentoVisibilidade.podeVerValores(lucia, p), isFalse);
      expect(orcamentoVisibilidade.podeVerValores(recepcao, p), isFalse);
    });
  });
}