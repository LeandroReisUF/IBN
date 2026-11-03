import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/pacientes/data/paciente_repository.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/plano_tratamento/data/plano_repository.dart';
import 'package:ibn/features/plano_tratamento/domain/plano_tratamento.dart';
import 'package:ibn/features/plano_tratamento/presentation/cubit/plano_cubit.dart';
import 'package:ibn/features/plano_tratamento/presentation/cubit/plano_state.dart';

// Mesmos ids das contas de teste do app (o Cubit consulta o `auth` global).
const davi = Usuario(id: '3', nome: 'Dr. Davi', email: 'dentista@clinica.local', perfil: Perfil.dentista);
const lucia = Usuario(id: '10', nome: 'Dra. Lúcia', email: 'dentista2@clinica.local', perfil: Perfil.dentista);
const recepcao = Usuario(id: '2', nome: 'Rita', email: 'recepcao@clinica.local', perfil: Perfil.recepcionista);

class _RepoQuebrado extends PlanoRepository {
  @override
  List<PlanoTratamento> planosDoPaciente(String pacienteId, {String? criadorId}) =>
      throw StateError('falhou');
}

void main() {
  late PlanoRepository repo;
  late PacienteRepository pacs;
  const espera = Duration(milliseconds: 10);

  setUp(() {
    repo = PlanoRepository();
    pacs = PacienteRepository(); // p1 (Maria) está vinculada só ao Dr. Davi (3) e à nutricionista (8)
  });

  /// O paciente é lido de novo a cada chamada: o encaminhamento muda os vínculos.
  PlanoCubit cubit(Usuario u) => PlanoCubit(
      repositorio: repo, pacientes: pacs, usuario: u, paciente: pacs.buscarPorId('p1')!);

  /// Plano do Dr. Davi com um item de valor "estranho" (R$ 987,65 e desconto R$ 12,34).
  Future<(PlanoTratamento, ItemPlano)> planoComItem() async {
    final c = cubit(davi);
    expect(await c.criarPlano('Reabilitação'), isNull);
    final plano = repo.planosDoPaciente('p1').single;
    expect(
      await c.adicionarItem(plano,
          procedimentoId: 'restauracao',
          dente: 26,
          instrucoes: 'Resina A2',
          valorCentavos: 98765,
          descontoCentavos: 1234),
      isNull,
    );
    await c.close();
    final atual = repo.planoPorId(plano.id)!;
    return (atual, atual.itens.single);
  }

  test('começa em Initial', () async {
    final c = cubit(davi);
    expect(c.state, isA<PlanoInitial>());
    await c.close();
  });

  group('carregar', () {
    blocTest<PlanoCubit, PlanoState>(
      'emite Loading e depois Success vazio',
      build: () => cubit(davi),
      act: (c) => c.carregar(),
      expect: () => [
        isA<PlanoLoading>(),
        isA<PlanoSuccess>()
            .having((s) => s.planos, 'planos', isEmpty)
            .having((s) => s.guias, 'guias', isEmpty),
      ],
    );

    blocTest<PlanoCubit, PlanoState>(
      'falha ao listar emite Error',
      build: () => PlanoCubit(
          repositorio: _RepoQuebrado(),
          pacientes: pacs,
          usuario: davi,
          paciente: pacs.buscarPorId('p1')!),
      act: (c) => c.carregar(),
      expect: () => [
        isA<PlanoLoading>(),
        isA<PlanoError>().having((e) => e.mensagem, 'mensagem', isNotEmpty),
      ],
    );

    blocTest<PlanoCubit, PlanoState>(
      'recarrega sozinho quando um plano é criado',
      build: () => cubit(davi),
      act: (c) async {
        await c.carregar();
        expect(await c.criarPlano('Plano A'), isNull);
      },
      wait: espera,
      expect: () => [
        isA<PlanoLoading>(),
        isA<PlanoSuccess>().having((s) => s.planos, 'planos', isEmpty),
        isA<PlanoSuccess>().having((s) => s.planos.length, 'planos', 1),
      ],
    );
  });

  group('planejar', () {
    test('sem vínculo e recepção não têm permissão', () async {
      for (final u in [lucia, recepcao]) {
        final c = cubit(u);
        expect(await c.criarPlano('Plano'), contains('permissão'), reason: u.nome);
        await c.close();
      }
      expect(repo.planosDoPaciente('p1'), isEmpty);
    });

    test('cria plano, adiciona item, define pagamento e gera logs', () async {
      final (plano, item) = await planoComItem();
      expect(item.valorCentavos, 98765);
      final c = cubit(davi);
      expect(await c.definirOrcamento(plano, FormaPagamento.cartaoCredito, 3), isNull);
      expect(repo.planoPorId(plano.id)!.orcamento!.parcelas, 3);
      expect(await c.definirOrcamento(plano, FormaPagamento.pix, 3), contains('parcelados'));
      for (final acao in ['criou_plano_tratamento', 'adicionou_item_plano', 'definiu_orcamento']) {
        expect(logsAcesso.todos.any((l) => l.acao == acao && l.entidadeId == 'p1'), isTrue,
            reason: acao);
      }
      await c.close();
    });

    test('o próprio criador marca como realizado e cancela itens', () async {
      final (plano, item) = await planoComItem();
      final c = cubit(davi);
      expect(await c.realizarMeuItem(plano, item), isNull);
      expect(repo.planoPorId(plano.id)!.itens.single.status, StatusItem.realizado);
      expect(await c.cancelarItem(plano, item), contains('realizado'));
      await c.close();
    });
  });

  group('RN04: encaminhar e executar', () {
    test('só dentista pode ser executante, e não o próprio criador', () async {
      final (plano, item) = await planoComItem();
      final c = cubit(davi);
      expect(await c.encaminhar(plano, item, '5'), contains('dentista')); // médica
      expect(await c.encaminhar(plano, item, 'zzz'), contains('dentista'));
      expect(await c.encaminhar(plano, item, '3'), contains('você mesmo'));
      expect(c.executantesPossiveis.map((u) => u.id), ['10']);
      expect(repo.planoPorId(plano.id)!.itens.single.status, StatusItem.planejado);
      await c.close();
    });

    test('encaminhar vincula o paciente ao executante (uma vez)', () async {
      final (plano, item) = await planoComItem();
      expect(pacs.buscarPorId('p1')!.profissionaisVinculados, isNot(contains('10')));
      final c = cubit(davi);
      expect(await c.encaminhar(plano, item, '10', instrucoes: 'Usar isolamento'), isNull);
      expect(pacs.buscarPorId('p1')!.profissionaisVinculados, containsAll(['3', '8', '10']));
      expect(logsAcesso.todos.any((l) => l.acao == 'encaminhou_procedimento'), isTrue);
      await c.close();
    });

    test('o executante vê a guia, nunca o plano nem os valores', () async {
      final (plano, item) = await planoComItem();
      final cDavi = cubit(davi);
      await cDavi.definirOrcamento(plano, FormaPagamento.cartaoCredito, 6);
      await cDavi.encaminhar(plano, item, '10', instrucoes: 'Usar isolamento');
      await cDavi.close();

      final c = cubit(lucia); // lê o paciente já vinculado
      await c.carregar();
      final estado = c.state as PlanoSuccess;
      expect(estado.planos, isEmpty); // nenhum plano (e portanto nenhum valor) no estado
      expect(estado.guias.length, 1);

      final guia = estado.guias.single;
      expect(guia.instrucoes, 'Usar isolamento');
      expect(guia.dente, 26);
      // Sem as datas (têm microssegundos que poderiam coincidir com algum número).
      final mapa = guia.paraMapa()
        ..remove('encaminhadoEm')
        ..remove('realizadoEm');
      final texto = '$mapa'.toLowerCase();
      for (final trecho in ['98765', '1234', 'valor', 'desconto', 'pagamento', 'parcela', 'r\$']) {
        expect(texto.contains(trecho), isFalse, reason: trecho);
      }
      await c.close();
    });

    test('o criador continua vendo os valores do próprio plano', () async {
      final (plano, item) = await planoComItem();
      final cDavi = cubit(davi);
      await cDavi.encaminhar(plano, item, '10');
      await cDavi.carregar();
      final estado = cDavi.state as PlanoSuccess;
      expect(estado.planos.single.totalNegociadoCentavos, 98765 - 1234);
      expect(estado.guias, isEmpty); // ele não é o executante
      await cDavi.close();
    });

    test('executar a guia: só o executante, e o item vira realizado', () async {
      final (plano, item) = await planoComItem();
      final cDavi = cubit(davi);
      await cDavi.encaminhar(plano, item, '10');
      final guia = repo.guiasDoExecutante('p1', '10').single;
      expect(await cDavi.executarGuia(guia), contains('recebeu o encaminhamento'));
      await cDavi.close();

      final c = cubit(lucia);
      expect(await c.executarGuia(guia), isNull);
      final feito = repo.planoPorId(plano.id)!.itens.single;
      expect(feito.status, StatusItem.realizado);
      expect(feito.realizadoPorId, '10');
      expect(logsAcesso.todos.any((l) => l.acao == 'realizou_procedimento_encaminhado'), isTrue);
      await c.close();
    });

    test('quem não está vinculado não executa guia', () async {
      final (plano, item) = await planoComItem();
      final cDavi = cubit(davi);
      await cDavi.encaminhar(plano, item, '10');
      final guia = repo.guiasDoExecutante('p1', '10').single;
      await cDavi.close();

      // Paciente como estava ANTES do encaminhamento (sem o vínculo da Dra. Lúcia).
      final semVinculo = Paciente(
        id: 'p1',
        nome: 'Maria',
        cpf: '52998224725',
        dataNascimento: DateTime(1985, 3, 12),
        telefone: '81987654321',
        termoLgpd: TermoLGPD(aceitoEm: DateTime(2026, 9, 2), versao: versaoTermoLgpd),
        profissionaisVinculados: const {'3'},
      );
      final c = PlanoCubit(repositorio: repo, pacientes: pacs, usuario: lucia, paciente: semVinculo);
      expect(await c.executarGuia(guia), contains('permissão'));
      expect(repo.planoPorId(plano.id)!.itens.single.status, StatusItem.encaminhado);
      await c.close();
    });
  });
}