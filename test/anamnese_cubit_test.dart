import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/features/anamnese/data/anamnese_repository.dart';
import 'package:ibn/features/anamnese/domain/anamnese.dart';
import 'package:ibn/features/anamnese/presentation/cubit/anamnese_cubit.dart';
import 'package:ibn/features/anamnese/presentation/cubit/anamnese_state.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'package:ibn/features/prontuario/domain/prontuario.dart';

const davi = Usuario(id: '3', nome: 'Dr. Davi', email: 'dentista@clinica.local', perfil: Perfil.dentista);
const lucia = Usuario(id: '10', nome: 'Dra. Lúcia', email: 'dentista2@clinica.local', perfil: Perfil.dentista);
const bia = Usuario(id: '4', nome: 'Bia', email: 'biomedico@clinica.local', perfil: Perfil.biomedico);
const marta = Usuario(id: '5', nome: 'Dra. Marta', email: 'medico@clinica.local', perfil: Perfil.medico);
const recepcao = Usuario(id: '2', nome: 'Rita', email: 'recepcao@clinica.local', perfil: Perfil.recepcionista);

/// Paciente vinculada ao Dr. Davi (3), à Bia (4) e à Dra. Marta (5).
Paciente maria({Set<String> vinculos = const {'3', '4', '5'}}) => Paciente(
      id: 'p1',
      nome: 'Maria',
      cpf: '52998224725',
      dataNascimento: DateTime(1985, 3, 12),
      telefone: '81987654321',
      termoLgpd: TermoLGPD(aceitoEm: DateTime(2026, 9, 2), versao: versaoTermoLgpd),
      profissionaisVinculados: vinculos,
    );

class _RepoQuebrado extends AnamneseRepository {
  _RepoQuebrado(ProntuarioRepository pr) : super(prontuario: pr);

  @override
  List<Anamnese> anamnesesDoPaciente(String pacienteId, {String? profissionalId}) =>
      throw StateError('falhou');
}

void main() {
  late ProntuarioRepository pr;
  late AnamneseRepository repo;
  const espera = Duration(milliseconds: 10);

  setUp(() {
    pr = ProntuarioRepository();
    repo = AnamneseRepository(prontuario: pr);
  });

  AnamneseCubit cubit(Usuario u, {Paciente? paciente}) => AnamneseCubit(
      repositorio: repo, prontuario: pr, usuario: u, paciente: paciente ?? maria());

  ModeloAnamnese odonto() => repo.modeloPorId('anamnese-odontologica')!;

  /// Respostas que cobrem todas as obrigatórias do modelo odontológico.
  Map<String, String> completas() => {
        'queixa': 'Dor no 26',
        'tratamento_medico': 'nao',
        'medicamentos': 'nenhum',
        'doencas': 'Nenhuma',
        'alergias': 'Nenhuma',
      };

  test('começa em Initial', () async {
    final c = cubit(davi);
    expect(c.state, isA<AnamneseInitial>());
    await c.close();
  });

  group('modelos por perfil', () {
    test('cada perfil recebe os modelos da sua especialidade e o geral', () async {
      final ids = {
        'dentista': cubit(davi).modelosDoUsuario.map((m) => m.id).toSet(),
        'biomedico': cubit(bia).modelosDoUsuario.map((m) => m.id).toSet(),
        'medico': cubit(marta).modelosDoUsuario.map((m) => m.id).toSet(),
      };
      expect(ids['dentista'], {'anamnese-odontologica', 'anamnese-geral'});
      expect(ids['biomedico'], {'anamnese-estetica', 'anamnese-geral'});
      expect(ids['medico'], {'anamnese-geral'});
    });
  });

  group('carregar', () {
    blocTest<AnamneseCubit, AnamneseState>(
      'emite Loading e depois Success vazio, com os modelos do perfil',
      build: () => cubit(davi),
      act: (c) => c.carregar(),
      expect: () => [
        isA<AnamneseLoading>(),
        isA<AnamneseSuccess>()
            .having((s) => s.anamneses, 'anamneses', isEmpty)
            .having((s) => s.modelos.length, 'modelos', 2),
      ],
    );

    blocTest<AnamneseCubit, AnamneseState>(
      'falha ao listar emite Error',
      build: () => AnamneseCubit(
          repositorio: _RepoQuebrado(pr), prontuario: pr, usuario: davi, paciente: maria()),
      act: (c) => c.carregar(),
      expect: () => [
        isA<AnamneseLoading>(),
        isA<AnamneseError>().having((e) => e.mensagem, 'mensagem', isNotEmpty),
      ],
    );

    blocTest<AnamneseCubit, AnamneseState>(
      'recarrega sozinho quando uma anamnese é salva',
      build: () => cubit(davi),
      act: (c) async {
        await c.carregar();
        expect(await c.salvar(odonto(), {'queixa': 'Dor'}), isNull);
      },
      wait: espera,
      expect: () => [
        isA<AnamneseLoading>(),
        isA<AnamneseSuccess>().having((s) => s.anamneses, 'anamneses', isEmpty),
        isA<AnamneseSuccess>().having((s) => s.anamneses.length, 'quantidade', 1),
      ],
    );

    blocTest<AnamneseCubit, AnamneseState>(
      'cada profissional vê só as próprias anamneses (RN03)',
      build: () {
        for (final (id, prof, modelo) in [
          ('an1', '3', 'anamnese-odontologica'),
          ('an2', '4', 'anamnese-estetica'),
        ]) {
          final m = repo.modeloPorId(modelo)!;
          repo.adicionarAnamnese(Anamnese(
            id: id,
            pacienteId: 'p1',
            profissionalId: prof,
            modeloId: m.id,
            titulo: m.nome,
            modeloVersao: m.versao,
            perguntas: m.perguntas,
            respostas: const {},
            criadaEm: DateTime.now(),
          ));
        }
        return cubit(davi);
      },
      act: (c) => c.carregar(),
      expect: () => [
        isA<AnamneseLoading>(),
        isA<AnamneseSuccess>().having((s) => s.anamneses.map((a) => a.id).toList(), 'ids', ['an1']),
      ],
    );
  });

  group('ações', () {
    test('sem vínculo e recepção não têm permissão', () async {
      for (final u in [lucia, recepcao]) {
        final c = cubit(u, paciente: maria(vinculos: {'3'}));
        expect(await c.salvar(odonto(), {'queixa': 'x'}), contains('permissão'), reason: u.nome);
        await c.close();
      }
      expect(repo.anamnesesDoPaciente('p1'), isEmpty);
    });

    test('assinar sem as obrigatórias é recusado e não cria rascunho', () async {
      final c = cubit(davi);
      final erro = await c.salvar(odonto(), {'queixa': 'Dor'}, assinar: true);
      expect(erro, contains('Responda'));
      expect(repo.anamnesesDoPaciente('p1'), isEmpty);
      await c.close();
    });

    test('salvar e assinar, depois nova versão com histórico', () async {
      final c = cubit(davi);
      expect(await c.salvar(odonto(), completas(), assinar: true), isNull);
      final primeira = repo.anamnesesDoPaciente('p1').single;
      expect(primeira.assinada, isTrue);
      expect(logsAcesso.todos.any((l) => l.acao == 'assinou_anamnese' && l.entidadeId == 'p1'), isTrue);

      final novas = {...completas(), 'medicamentos': 'Losartana'};
      expect(await c.salvar(odonto(), novas, anterior: primeira, assinar: true), isNull);
      expect(repo.anamnesesDoPaciente('p1').length, 2);
      expect(repo.substituidas('p1'), {primeira.id});
      expect(repo.porId(primeira.id)!.respostas['medicamentos'], 'nenhum');
      expect(logsAcesso.todos.any((l) => l.acao == 'atualizou_anamnese'), isTrue);
      await c.close();
    });

    test('liga ao atendimento em aberto, quando existe', () async {
      pr.iniciarAtendimento(Atendimento(
          id: 'a1', pacienteId: 'p1', profissionalId: '3', inicio: DateTime.now()));
      final c = cubit(davi);
      await c.salvar(odonto(), {'queixa': 'Dor'});
      expect(repo.anamnesesDoPaciente('p1').single.atendimentoId, 'a1');
      await c.close();
    });

    test('rascunho: editar, completar, assinar e descartar', () async {
      final c = cubit(davi);
      await c.salvar(odonto(), {'queixa': 'Dor'});
      final rascunho = repo.anamnesesDoPaciente('p1').single;

      expect(await c.atualizarRascunho(rascunho, {'queixa': 'Dor', 'dor': '99'}),
          contains('Intensidade da dor'));
      expect(await c.atualizarRascunho(rascunho, {'queixa': 'Dor'}, assinar: true), contains('Responda'));
      expect(repo.porId(rascunho.id)!.assinada, isFalse);

      expect(await c.atualizarRascunho(rascunho, completas(), assinar: true), isNull);
      final assinada = repo.porId(rascunho.id)!;
      expect(assinada.assinada, isTrue);
      expect(await c.atualizarRascunho(assinada, {'queixa': 'x'}), contains('RN05'));
      expect(await c.descartarRascunho(assinada), contains('RN05'));
      await c.close();

      final c2 = cubit(davi);
      await c2.salvar(repo.modeloPorId('anamnese-geral')!, {'queixa': 'Outro'});
      final outro = repo.anamnesesDoPaciente('p1').first;
      expect(await c2.descartarRascunho(outro), isNull);
      expect(repo.porId(outro.id), isNull);
      await c2.close();
    });
  });
    group('compartilhamento por especialidade', () {
    final vinculos = {'3', '4', '5', '10'};

    test('colega da mesma especialidade vê as ASSINADAS, mas não rascunhos nem modelo geral', () async {
      final cDavi = cubit(davi, paciente: maria(vinculos: vinculos));
      expect(await cDavi.salvar(odonto(), completas(), assinar: true), isNull);
      expect(
        await cDavi.salvar(
          repo.modeloPorId('anamnese-geral')!,
          {'queixa': 'x', 'doencas': 'Nenhuma', 'medicamentos': 'nenhum', 'alergias': 'nenhuma'},
          assinar: true,
        ),
        isNull,
      );
      expect(await cDavi.salvar(odonto(), {'queixa': 'rascunho'}), isNull);

      await cDavi.carregar();
      expect((cDavi.state as AnamneseSuccess).anamneses.length, 3); // ele vê as próprias

      final cLucia = cubit(lucia, paciente: maria(vinculos: vinculos));
      await cLucia.carregar();
      final deLucia = (cLucia.state as AnamneseSuccess).anamneses;
      expect(deLucia.length, 1);
      expect(deLucia.single.modeloId, 'anamnese-odontologica');
      expect(deLucia.single.assinada, isTrue);
      expect(deLucia.single.profissionalId, '3');

      final cBia = cubit(bia, paciente: maria(vinculos: vinculos));
      await cBia.carregar();
      expect((cBia.state as AnamneseSuccess).anamneses, isEmpty); // outra especialidade

      await cDavi.close();
      await cLucia.close();
      await cBia.close();
    });

    test('o colega vê, mas só o autor cria nova versão', () async {
      final cDavi = cubit(davi, paciente: maria(vinculos: vinculos));
      await cDavi.salvar(odonto(), completas(), assinar: true);
      final doDavi = repo.anamnesesDoPaciente('p1').single;

      final cLucia = cubit(lucia, paciente: maria(vinculos: vinculos));
      expect(await cLucia.salvar(odonto(), completas(), anterior: doDavi, assinar: true),
          contains('autor'));
      await cDavi.close();
      await cLucia.close();
    });
  });
}