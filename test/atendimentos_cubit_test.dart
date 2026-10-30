import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/features/agenda/data/agenda_service.dart';
import 'package:ibn/features/agenda/domain/agendamento.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'package:ibn/features/prontuario/domain/prontuario.dart';
import 'package:ibn/features/prontuario/presentation/cubit/atendimentos_cubit.dart';
import 'package:ibn/features/prontuario/presentation/cubit/atendimentos_state.dart';

const davi = Usuario(id: '3', nome: 'Dr. Davi', email: 'dentista@clinica.local', perfil: Perfil.dentista);
const lucia = Usuario(id: '10', nome: 'Dra. Lúcia', email: 'dentista2@clinica.local', perfil: Perfil.dentista);

/// Paciente p1 vinculado só ao Dr. Davi (id 3).
Paciente paciente() => Paciente(
      id: 'p1',
      nome: 'Maria das Dores Silva',
      cpf: '52998224725',
      dataNascimento: DateTime(1985, 3, 12),
      telefone: '81987654321',
      termoLgpd: TermoLGPD(aceitoEm: DateTime(2026, 9, 2), versao: versaoTermoLgpd),
      profissionaisVinculados: const {'3'},
    );

/// Consulta do Dr. Davi hoje às 23:00 (Sala 3), para testar o vínculo com a agenda.
Agendamento consultaHoje(String id) {
  final n = DateTime.now();
  final ini = DateTime(n.year, n.month, n.day, 23);
  return Agendamento(
    id: id,
    pacienteId: 'p1',
    profissionalId: '3',
    salaNumero: 3,
    procedimentoId: 'consulta-odontologica',
    inicio: ini,
    fim: ini.add(const Duration(minutes: 30)),
  );
}

class _RepoQuebrado extends ProntuarioRepository {
  @override
  List<Atendimento> atendimentosDoPaciente(String pacienteId, {String? profissionalId}) =>
      throw StateError('falhou');
}

void main() {
  late ProntuarioRepository repo;
  late AgendaService agendaSvc;

  setUp(() {
    repo = ProntuarioRepository();
    agendaSvc = AgendaService(comExemplos: false);
  });

  AtendimentosCubit criar({Usuario usuario = davi, ProntuarioRepository? repositorio}) =>
      AtendimentosCubit(
        repositorio: repositorio ?? repo,
        agendaService: agendaSvc,
        usuario: usuario,
        paciente: paciente(),
      );

  /// Deixa as emissões assíncronas do Cubit terminarem.
  Future<void> pump() => Future<void>.delayed(Duration.zero);

  AtendimentosSuccess sucesso(AtendimentosCubit c) => c.state as AtendimentosSuccess;

  /// Cubit já carregado com um atendimento aberto e uma evolução em rascunho.
  Future<AtendimentosCubit> comRascunho() async {
    final c = criar();
    await c.carregar();
    expect(await c.iniciar(), isNull);
    await pump();
    final id = sucesso(c).atendimentos.single.atendimento.id;
    expect(await c.adicionarEvolucao(id, TipoEvolucao.livre, 'Dor no 26.'), isNull);
    await pump();
    return c;
  }

  test('começa em Initial', () async {
    final c = criar();
    expect(c.state, isA<AtendimentosInitial>());
    await c.close();
  });

  group('carregar', () {
    blocTest<AtendimentosCubit, AtendimentosState>(
      'Loading e depois Success vazio',
      build: criar,
      act: (c) => c.carregar(),
      expect: () => [
        isA<AtendimentosLoading>(),
        isA<AtendimentosSuccess>()
            .having((s) => s.atendimentos, 'atendimentos', isEmpty)
            .having((s) => s.temAtivo, 'temAtivo', isFalse),
      ],
    );

    blocTest<AtendimentosCubit, AtendimentosState>(
      'cada profissional vê só os próprios atendimentos (RN03)',
      build: () {
        final base = DateTime(2026, 10, 28, 9);
        repo.iniciarAtendimento(Atendimento(
            id: 'a1', pacienteId: 'p1', profissionalId: '3', inicio: base));
        repo.iniciarAtendimento(Atendimento(
            id: 'a2', pacienteId: 'p1', profissionalId: '10', inicio: base));
        return criar();
      },
      act: (c) => c.carregar(),
      expect: () => [
        isA<AtendimentosLoading>(),
        isA<AtendimentosSuccess>().having(
            (s) => s.atendimentos.map((d) => d.atendimento.id).toList(), 'ids', ['a1']),
      ],
    );

    blocTest<AtendimentosCubit, AtendimentosState>(
      'falha ao listar emite Error',
      build: () => criar(repositorio: _RepoQuebrado()),
      act: (c) => c.carregar(),
      expect: () => [
        isA<AtendimentosLoading>(),
        isA<AtendimentosError>().having((e) => e.mensagem, 'mensagem', isNotEmpty),
      ],
    );
  });

  group('acesso', () {
    test('profissional sem vínculo com o paciente não inicia atendimento', () async {
      final c = criar(usuario: lucia);
      await c.carregar();
      final erro = await c.iniciar();
      expect(erro, contains('acesso'));
      await pump();
      expect(sucesso(c).atendimentos, isEmpty);
      await c.close();
    });
  });

  group('iniciar', () {
    test('sem agendamento: cria atendimento em aberto e registra o log', () async {
      final c = criar();
      await c.carregar();
      expect(await c.iniciar(), isNull);
      await pump();
      expect(sucesso(c).temAtivo, isTrue);
      expect(sucesso(c).atendimentos.single.atendimento.agendamentoId, isNull);
      expect(logsAcesso.todos.last.acao, 'iniciou_atendimento');
      expect(logsAcesso.todos.last.usuarioId, '3');
      await c.close();
    });

    test('não permite dois atendimentos abertos', () async {
      final c = criar();
      await c.carregar();
      await c.iniciar();
      expect(await c.iniciar(), isNotNull);
      await c.close();
    });

    test('vinculado ao agendamento de hoje: status vira Em atendimento', () async {
      agendaSvc.criar(consultaHoje('g1'));
      final c = criar();
      expect(c.agendamentosIniciaveisHoje().map((a) => a.id), ['g1']);

      await c.carregar();
      expect(await c.iniciar(agendamentoId: 'g1'), isNull);
      await pump();

      expect(agendaSvc.todos.firstWhere((a) => a.id == 'g1').status,
          StatusAgendamento.emAtendimento);
      expect(c.agendamentosIniciaveisHoje(), isEmpty); // não pode ligar de novo
      await c.close();
    });

    test('agendamento de outro dia ou de outro profissional não é oferecido', () async {
      final amanha = DateTime.now().add(const Duration(days: 1));
      final ini = DateTime(amanha.year, amanha.month, amanha.day, 9);
      agendaSvc.criar(Agendamento(
        id: 'g2',
        pacienteId: 'p1',
        profissionalId: '3',
        salaNumero: 3,
        procedimentoId: 'consulta-odontologica',
        inicio: ini,
        fim: ini.add(const Duration(minutes: 30)),
      ));
      final c = criar();
      expect(c.agendamentosIniciaveisHoje(), isEmpty);
      await c.close();
    });
  });

  group('evolução (RN05)', () {
    test('nasce como rascunho e aparece no estado', () async {
      final c = await comRascunho();
      final e = sucesso(c).atendimentos.single.evolucoes.single.evolucao;
      expect(e.assinada, isFalse);
      expect(e.texto, 'Dor no 26.');
      await c.close();
    });

    test('rascunho pode ser editado e descartado', () async {
      final c = await comRascunho();
      var e = sucesso(c).atendimentos.single.evolucoes.single.evolucao;
      expect(await c.atualizarRascunho(e, 'Texto novo'), isNull);
      await pump();
      e = sucesso(c).atendimentos.single.evolucoes.single.evolucao;
      expect(e.texto, 'Texto novo');

      expect(await c.descartarRascunho(e), isNull);
      await pump();
      expect(sucesso(c).atendimentos.single.evolucoes, isEmpty);
      await c.close();
    });

    test('assinada não edita nem descarta; assinar registra o log', () async {
      final c = await comRascunho();
      var e = sucesso(c).atendimentos.single.evolucoes.single.evolucao;
      expect(await c.assinar(e), isNull);
      expect(logsAcesso.todos.last.acao, 'assinou_evolucao');
      await pump();
      e = sucesso(c).atendimentos.single.evolucoes.single.evolucao;
      expect(e.assinada, isTrue);
      expect(e.selo, isNotNull);

      expect(await c.atualizarRascunho(e, 'Tentativa'), isNotNull);
      expect(await c.descartarRascunho(e), isNotNull);
      await c.close();
    });
  });

  group('encerrar', () {
    test('bloqueia com rascunho pendente e encerra depois de assinar', () async {
      agendaSvc.criar(consultaHoje('g1'));
      final c = criar();
      await c.carregar();
      await c.iniciar(agendamentoId: 'g1');
      await pump();
      final id = sucesso(c).atendimentos.single.atendimento.id;
      await c.adicionarEvolucao(id, TipoEvolucao.procedimento, 'Restauração do 26.');
      await pump();

      expect(await c.encerrar(id), isNotNull); // rascunho pendente
      expect(sucesso(c).temAtivo, isTrue);

      final e = sucesso(c).atendimentos.single.evolucoes.single.evolucao;
      await c.assinar(e);
      expect(await c.encerrar(id, observacoes: 'Tudo certo'), isNull);
      await pump();

      final a = sucesso(c).atendimentos.single.atendimento;
      expect(a.encerrado, isTrue);
      expect(a.observacoesEncerramento, 'Tudo certo');
      expect(sucesso(c).temAtivo, isFalse);
      expect(agendaSvc.todos.firstWhere((x) => x.id == 'g1').status, StatusAgendamento.atendido);
      expect(logsAcesso.todos.last.acao, 'encerrou_atendimento');
      await c.close();
    });
  });

  group('adendo (RN05)', () {
    test('só para evolução assinada; funciona depois de encerrar; original intacta', () async {
      final c = await comRascunho();
      var item = sucesso(c).atendimentos.single.evolucoes.single;
      expect(await c.adicionarAdendo(item.evolucao, 'Erro de digitação', 'Leia-se 16.'), isNotNull);

      await c.assinar(item.evolucao);
      await pump();
      item = sucesso(c).atendimentos.single.evolucoes.single;
      final seloOriginal = item.evolucao.selo;

      await c.encerrar(sucesso(c).atendimentos.single.atendimento.id);
      expect(await c.adicionarAdendo(item.evolucao, 'Erro de digitação', 'Leia-se 16.'), isNull);
      await pump();

      item = sucesso(c).atendimentos.single.evolucoes.single;
      expect(item.adendos.length, 1);
      expect(item.adendos.single.assinado, isTrue);
      expect(item.evolucao.texto, 'Dor no 26.');
      expect(item.evolucao.selo, seloOriginal);
      expect(logsAcesso.todos.last.acao, 'registrou_adendo');
      await c.close();
    });

    test('exige justificativa', () async {
      final c = await comRascunho();
      final e = sucesso(c).atendimentos.single.evolucoes.single.evolucao;
      await c.assinar(e);
      expect(await c.adicionarAdendo(e, 'a', 'Texto'), isNotNull);
      await c.close();
    });
  });

  test('depois de fechado, mudanças no repositório não causam erro', () async {
    final c = criar();
    await c.carregar();
    await c.close();
    expect(
      () => repo.iniciarAtendimento(Atendimento(
          id: 'x', pacienteId: 'p1', profissionalId: '3', inicio: DateTime(2026, 10, 28))),
      returnsNormally,
    );
    await pump();
    expect(c.isClosed, isTrue);
  });
}