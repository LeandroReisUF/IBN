import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/pacientes/data/paciente_repository.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/pacientes/presentation/cubit/pacientes_cubit.dart';
import 'package:ibn/features/pacientes/presentation/cubit/pacientes_state.dart';

const admin = Usuario(id: '1', nome: 'Ana Admin', email: 'admin@clinica.local', perfil: Perfil.administrador);
const recepcao = Usuario(id: '2', nome: 'Rita Recepção', email: 'recepcao@clinica.local', perfil: Perfil.recepcionista);
const davi = Usuario(id: '3', nome: 'Dr. Davi', email: 'dentista@clinica.local', perfil: Perfil.dentista);
const lucia = Usuario(id: '10', nome: 'Dra. Lúcia', email: 'dentista2@clinica.local', perfil: Perfil.dentista);

/// O repositório novo já traz 4 pacientes de exemplo:
/// p1 {3,8} · p2 {5,3} · p3 {4,9} · p4 {3,7}.
Paciente novo({String id = 'n1', String cpf = '39053344705', String nome = 'Paciente Novo'}) => Paciente(
      id: id,
      nome: nome,
      cpf: cpf,
      dataNascimento: DateTime(1990, 5, 10),
      telefone: '81999990000',
      termoLgpd: TermoLGPD(aceitoEm: DateTime(2026, 10, 1), versao: versaoTermoLgpd),
    );

class _RepoQuebrado extends PacienteRepository {
  @override
  List<Paciente> get todos => throw StateError('falhou');
}

void main() {
  late PacienteRepository repo;
  const espera = Duration(milliseconds: 10);

  setUp(() {
    repo = PacienteRepository();
  });

  PacientesCubit cubit(Usuario u) => PacientesCubit(repositorio: repo, usuario: u);

  test('começa em Initial', () async {
    final c = cubit(admin);
    expect(c.state, isA<PacientesInitial>());
    await c.close();
  });

  group('carregar (RN03)', () {
    blocTest<PacientesCubit, PacientesState>(
      'Recepção recebe todos os pacientes',
      build: () => cubit(recepcao),
      act: (c) => c.carregar(),
      expect: () => [
        isA<PacientesLoading>(),
        isA<PacientesSuccess>().having((s) => s.pacientes.length, 'quantidade', 4),
      ],
    );

    blocTest<PacientesCubit, PacientesState>(
      'Dr. Davi recebe só os pacientes vinculados a ele',
      build: () => cubit(davi),
      act: (c) => c.carregar(),
      expect: () => [
        isA<PacientesLoading>(),
        isA<PacientesSuccess>().having(
            (s) => s.pacientes.map((p) => p.id).toSet(), 'ids', {'p1', 'p2', 'p4'}),
      ],
    );

    blocTest<PacientesCubit, PacientesState>(
      'Dra. Lúcia (sem vínculos) não recebe nenhum',
      build: () => cubit(lucia),
      act: (c) => c.carregar(),
      expect: () => [
        isA<PacientesLoading>(),
        isA<PacientesSuccess>().having((s) => s.pacientes, 'pacientes', isEmpty),
      ],
    );

    blocTest<PacientesCubit, PacientesState>(
      'falha ao listar emite Error',
      build: () => PacientesCubit(repositorio: _RepoQuebrado(), usuario: admin),
      act: (c) => c.carregar(),
      expect: () => [
        isA<PacientesLoading>(),
        isA<PacientesError>().having((e) => e.mensagem, 'mensagem', isNotEmpty),
      ],
    );
  });

  group('reação ao repositório', () {
    blocTest<PacientesCubit, PacientesState>(
      'sem ter carregado, mudanças no repositório não emitem',
      build: () => cubit(recepcao),
      act: (c) => repo.definirAtivo('p1', false),
      wait: espera,
      expect: () => <Matcher>[],
    );

    blocTest<PacientesCubit, PacientesState>(
      'atualiza sozinho quando outra parte do app muda o paciente (ex.: Agenda vincula)',
      build: () => cubit(recepcao),
      act: (c) async {
        await c.carregar();
        repo.definirAtivo('p1', false);
      },
      wait: espera,
      expect: () => [
        isA<PacientesLoading>(),
        isA<PacientesSuccess>()
            .having((s) => s.pacientes.firstWhere((p) => p.id == 'p1').ativo, 'ativo', isTrue),
        isA<PacientesSuccess>()
            .having((s) => s.pacientes.firstWhere((p) => p.id == 'p1').ativo, 'ativo', isFalse),
      ],
    );

    test('depois de fechado, mudanças no repositório não causam erro', () async {
      final c = cubit(recepcao);
      await c.carregar();
      await c.close();
      expect(() => repo.definirAtivo('p1', false), returnsNormally);
      await Future<void>.delayed(espera);
      expect(c.isClosed, isTrue);
    });
  });

  group('salvar', () {
    blocTest<PacientesCubit, PacientesState>(
      'cadastra paciente novo e a lista recarrega',
      build: () => cubit(recepcao),
      act: (c) async {
        await c.carregar();
        expect(await c.salvar(novo()), isNull);
      },
      wait: espera,
      expect: () => [
        isA<PacientesLoading>(),
        isA<PacientesSuccess>().having((s) => s.pacientes.length, 'quantidade', 4),
        isA<PacientesSuccess>().having((s) => s.pacientes.length, 'quantidade', 5),
      ],
    );

    blocTest<PacientesCubit, PacientesState>(
      'sem permissão (dentista) devolve erro e NÃO troca o estado',
      build: () => cubit(davi),
      act: (c) async {
        await c.carregar();
        final erro = await c.salvar(novo());
        expect(erro, isNotNull);
        expect(erro, contains('permissão'));
      },
      wait: espera,
      expect: () => [
        isA<PacientesLoading>(),
        isA<PacientesSuccess>().having((s) => s.pacientes.length, 'quantidade', 3),
      ],
    );

    test('recusa CPF inválido, CPF duplicado e nome vazio', () async {
      final c = cubit(recepcao);
      expect(await c.salvar(novo(cpf: '11111111111')), 'CPF inválido.');
      expect(await c.salvar(novo(cpf: '52998224725')), 'CPF já cadastrado.'); // CPF da p1
      expect(await c.salvar(novo(nome: '  ')), isNotNull);
      expect(repo.todos.length, 4);
      await c.close();
    });

    test('editar o próprio cadastro (mesmo CPF e mesmo id) é permitido', () async {
      final c = cubit(recepcao);
      final p1 = repo.buscarPorId('p1')!;
      expect(await c.salvar(p1), isNull);
      await c.close();
    });
  });

  group('inativar e excluir', () {
    blocTest<PacientesCubit, PacientesState>(
      'Recepção inativa e a lista atualiza',
      build: () => cubit(recepcao),
      act: (c) async {
        await c.carregar();
        expect(await c.definirAtivo('p1', false), isNull);
      },
      wait: espera,
      expect: () => [
        isA<PacientesLoading>(),
        isA<PacientesSuccess>(),
        isA<PacientesSuccess>()
            .having((s) => s.pacientes.firstWhere((p) => p.id == 'p1').ativo, 'ativo', isFalse),
      ],
    );

    test('dentista não inativa; paciente inexistente devolve erro', () async {
      final d = cubit(davi);
      expect(await d.definirAtivo('p1', false), isNotNull);
      await d.close();
      final r = cubit(recepcao);
      expect(await r.definirAtivo('zzz', false), 'Paciente não encontrado.');
      await r.close();
    });

    test('só o Administrador exclui, e só quem não tem histórico', () async {
      final a = cubit(admin);
      expect(await a.salvar(novo()), isNull);
      expect(await a.excluir('n1'), isNull); // sem vínculo nem atendimento
      expect(repo.buscarPorId('n1'), isNull);

      final erroHistorico = await a.excluir('p1'); // tem profissionais vinculados
      expect(erroHistorico, contains('histórico'));
      expect(repo.buscarPorId('p1'), isNotNull);
      await a.close();

      final r = cubit(recepcao);
      expect(await r.excluir('p1'), contains('Administrador'));
      await r.close();
    });

    test('cpfJaCadastrado e novoId delegam ao repositório', () async {
      final c = cubit(recepcao);
      expect(c.cpfJaCadastrado('52998224725'), isTrue);
      expect(c.cpfJaCadastrado('52998224725', ignorarId: 'p1'), isFalse);
      expect(c.novoId(), isNotEmpty);
      await c.close();
    });
  });
}