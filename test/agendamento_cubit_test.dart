import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/features/agenda/data/agenda_service.dart';
import 'package:ibn/features/agenda/domain/agendamento.dart';
import 'package:ibn/features/agenda/presentation/cubit/agendamento_cubit.dart';
import 'package:ibn/features/agenda/presentation/cubit/agendamento_state.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/auth/domain/usuario.dart';

const admin = Usuario(
  id: '1',
  nome: 'Ana Admin',
  email: 'admin@clinica.local',
  perfil: Perfil.administrador,
);
const dentista = Usuario(
  id: '3',
  nome: 'Dr. Davi',
  email: 'dentista@clinica.local',
  perfil: Perfil.dentista,
);

DateTime _h(int hora, [int min = 0]) => DateTime(2030, 1, 10, hora, min);

/// Consulta odontológica do Dr. Davi (id 3) na Sala 3.
Agendamento odonto(String id, {DateTime? inicio}) {
  final ini = inicio ?? _h(9);
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

/// Consulta médica da Dra. Marta (id 5) na Sala 1.
Agendamento medica(String id) {
  final ini = _h(9);
  return Agendamento(
    id: id,
    pacienteId: 'p1',
    profissionalId: '5',
    salaNumero: 1,
    procedimentoId: 'consulta-medica',
    inicio: ini,
    fim: ini.add(const Duration(minutes: 30)),
  );
}

/// Serviço que falha ao listar: serve para provocar o estado Error.
class _ServicoQuebrado extends AgendaService {
  _ServicoQuebrado() : super(comExemplos: false);

  @override
  List<Agendamento> get todos => throw StateError('falhou');
}

void main() {
  late AgendaService servico;

  setUp(() {
    servico = AgendaService(comExemplos: false);
  });

  const espera = Duration(milliseconds: 10);

  test('começa em Initial', () async {
    final cubit = AgendamentoCubit(servico: servico, usuario: admin);
    expect(cubit.state, isA<AgendamentoInitial>());
    await cubit.close();
  });

  group('carregar', () {
    blocTest<AgendamentoCubit, AgendamentoState>(
      'emite Loading e depois Success (lista vazia)',
      build: () => AgendamentoCubit(servico: servico, usuario: admin),
      act: (c) => c.carregar(),
      expect: () => [
        isA<AgendamentoLoading>(),
        isA<AgendamentoSuccess>().having((s) => s.consultas, 'consultas', isEmpty),
      ],
    );

    blocTest<AgendamentoCubit, AgendamentoState>(
      'Admin recebe todos os agendamentos',
      build: () {
        servico.criar(odonto('a1'));
        servico.criar(medica('a2'));
        return AgendamentoCubit(servico: servico, usuario: admin);
      },
      act: (c) => c.carregar(),
      expect: () => [
        isA<AgendamentoLoading>(),
        isA<AgendamentoSuccess>().having((s) => s.consultas.length, 'quantidade', 2),
      ],
    );

    blocTest<AgendamentoCubit, AgendamentoState>(
      'RN03: dentista recebe só os próprios atendimentos',
      build: () {
        servico.criar(odonto('a1'));
        servico.criar(medica('a2'));
        return AgendamentoCubit(servico: servico, usuario: dentista);
      },
      act: (c) => c.carregar(),
      expect: () => [
        isA<AgendamentoLoading>(),
        isA<AgendamentoSuccess>()
            .having((s) => s.consultas.map((a) => a.id).toList(), 'ids', ['a1']),
      ],
    );

    blocTest<AgendamentoCubit, AgendamentoState>(
      'falha ao listar emite Error com mensagem',
      build: () => AgendamentoCubit(servico: _ServicoQuebrado(), usuario: admin),
      act: (c) => c.carregar(),
      expect: () => [
        isA<AgendamentoLoading>(),
        isA<AgendamentoError>().having((e) => e.mensagem, 'mensagem', isNotEmpty),
      ],
    );
  });

  group('reação ao serviço', () {
    blocTest<AgendamentoCubit, AgendamentoState>(
      'sem ter carregado, mudanças no serviço não emitem nada',
      build: () => AgendamentoCubit(servico: servico, usuario: admin),
      act: (c) => servico.criar(odonto('a1')),
      wait: espera,
      expect: () => <Matcher>[],
    );

    blocTest<AgendamentoCubit, AgendamentoState>(
      'atualiza sozinho quando outra tela muda a agenda (ex.: Prontuário)',
      build: () {
        servico.criar(odonto('a1'));
        return AgendamentoCubit(servico: servico, usuario: admin);
      },
      act: (c) async {
        await c.carregar();
        servico.mudarStatus('a1', StatusAgendamento.emAtendimento);
      },
      wait: espera,
      expect: () => [
        isA<AgendamentoLoading>(),
        isA<AgendamentoSuccess>().having(
            (s) => s.consultas.single.status, 'status', StatusAgendamento.agendado),
        isA<AgendamentoSuccess>().having(
            (s) => s.consultas.single.status, 'status', StatusAgendamento.emAtendimento),
      ],
    );

    test('depois de fechado, mudanças no serviço não causam erro', () async {
      final cubit = AgendamentoCubit(servico: servico, usuario: admin);
      await cubit.carregar();
      await cubit.close();
      expect(() => servico.criar(odonto('a1')), returnsNormally);
      await Future<void>.delayed(espera);
      expect(cubit.isClosed, isTrue);
    });
  });

  group('ações', () {
    blocTest<AgendamentoCubit, AgendamentoState>(
      'criar com sucesso devolve null e a lista recarrega',
      build: () => AgendamentoCubit(servico: servico, usuario: admin),
      act: (c) async {
        await c.carregar();
        final erro = await c.criar(odonto('a1'));
        expect(erro, isNull);
      },
      wait: espera,
      expect: () => [
        isA<AgendamentoLoading>(),
        isA<AgendamentoSuccess>().having((s) => s.consultas, 'consultas', isEmpty),
        isA<AgendamentoSuccess>().having((s) => s.consultas.length, 'quantidade', 1),
      ],
    );

    blocTest<AgendamentoCubit, AgendamentoState>(
      'RN02: conflito devolve a mensagem e NÃO troca o estado',
      build: () {
        servico.criar(odonto('a1'));
        return AgendamentoCubit(servico: servico, usuario: admin);
      },
      act: (c) async {
        await c.carregar();
        final erro = await c.criar(odonto('a2')); // mesma sala, mesmo horário
        expect(erro, isNotNull);
        expect(erro, contains('Sala 3'));
      },
      wait: espera,
      expect: () => [
        isA<AgendamentoLoading>(),
        isA<AgendamentoSuccess>().having((s) => s.consultas.length, 'quantidade', 1),
      ],
    );

    blocTest<AgendamentoCubit, AgendamentoState>(
      'mudarStatus atualiza a lista',
      build: () {
        servico.criar(odonto('a1'));
        return AgendamentoCubit(servico: servico, usuario: admin);
      },
      act: (c) async {
        await c.carregar();
        final erro = await c.mudarStatus('a1', StatusAgendamento.atendido);
        expect(erro, isNull);
      },
      wait: espera,
      expect: () => [
        isA<AgendamentoLoading>(),
        isA<AgendamentoSuccess>(),
        isA<AgendamentoSuccess>().having(
            (s) => s.consultas.single.status, 'status', StatusAgendamento.atendido),
      ],
    );

    test('validarConflitos e novoId delegam ao serviço', () async {
      servico.criar(odonto('a1'));
      final cubit = AgendamentoCubit(servico: servico, usuario: admin);
      expect(cubit.validarConflitos(odonto('a2')), isNotNull);
      expect(cubit.validarConflitos(odonto('a3', inicio: _h(11))), isNull);
      expect(cubit.novoId(), isNotEmpty);
      await cubit.close();
    });
  });
}