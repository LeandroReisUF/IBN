import 'dart:typed_data';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/exames/data/exames_repository.dart';
import 'package:ibn/features/exames/domain/exames.dart';
import 'package:ibn/features/exames/presentation/cubit/exames_cubit.dart';
import 'package:ibn/features/exames/presentation/cubit/exames_state.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'package:ibn/features/prontuario/domain/prontuario.dart';

const davi = Usuario(id: '3', nome: 'Dr. Davi', email: 'dentista@clinica.local', perfil: Perfil.dentista);
const lucia = Usuario(id: '10', nome: 'Dra. Lúcia', email: 'dentista2@clinica.local', perfil: Perfil.dentista);
const recepcao = Usuario(id: '2', nome: 'Rita', email: 'recepcao@clinica.local', perfil: Perfil.recepcionista);

/// Paciente vinculado só ao Dr. Davi (id 3).
Paciente maria() => Paciente(
      id: 'p1',
      nome: 'Maria',
      cpf: '52998224725',
      dataNascimento: DateTime(1985, 3, 12),
      telefone: '81987654321',
      termoLgpd: TermoLGPD(aceitoEm: DateTime(2026, 9, 2), versao: versaoTermoLgpd),
      profissionaisVinculados: {'3'},
    );

class _RepoQuebrado extends ExamesRepository {
  _RepoQuebrado(ProntuarioRepository pr) : super(prontuario: pr);

  @override
  List<Exame> examesDoPaciente(String pacienteId, {String? profissionalId}) =>
      throw StateError('falhou');
}

void main() {
  late ProntuarioRepository pr;
  late ExamesRepository repo;
  const espera = Duration(milliseconds: 10);

  setUp(() {
    pr = ProntuarioRepository();
    repo = ExamesRepository(prontuario: pr);
  });

  ExamesCubit cubit(Usuario u) =>
      ExamesCubit(repositorio: repo, prontuario: pr, usuario: u, paciente: maria());

  void iniciarAtendimento(String prof) {
    expect(
      pr.iniciarAtendimento(Atendimento(
          id: 'a-$prof', pacienteId: 'p1', profissionalId: prof, inicio: DateTime.now())),
      isNull,
    );
  }

  Future<String?> solicitarBasico(ExamesCubit c) =>
      c.solicitar(tipo: TipoExame.imagem, nome: 'Radiografia panorâmica');

  Uint8List bytes() => Uint8List.fromList([1, 2, 3]);

  test('começa em Initial', () async {
    final c = cubit(davi);
    expect(c.state, isA<ExamesInitial>());
    await c.close();
  });

  group('carregar', () {
    blocTest<ExamesCubit, ExamesState>(
      'emite Loading e depois Success vazio',
      build: () => cubit(davi),
      act: (c) => c.carregar(),
      expect: () => [
        isA<ExamesLoading>(),
        isA<ExamesSuccess>().having((s) => s.exames, 'exames', isEmpty),
      ],
    );

    blocTest<ExamesCubit, ExamesState>(
      'cada dentista vê só os exames que solicitou (RN03)',
      build: () {
        iniciarAtendimento('3');
        iniciarAtendimento('10');
        final agora = DateTime.now();
        for (final (id, prof) in [('e1', '3'), ('e2', '10')]) {
          repo.solicitarExame(Exame(
            id: id,
            pacienteId: 'p1',
            atendimentoId: 'a-$prof',
            profissionalId: prof,
            tipo: TipoExame.imagem,
            nome: 'Exame $id',
            solicitadoEm: agora,
            atualizadoEm: agora,
          ));
        }
        return cubit(davi);
      },
      act: (c) => c.carregar(),
      expect: () => [
        isA<ExamesLoading>(),
        isA<ExamesSuccess>().having((s) => s.exames.map((e) => e.id).toList(), 'ids', ['e1']),
      ],
    );

    blocTest<ExamesCubit, ExamesState>(
      'falha ao listar emite Error',
      build: () => ExamesCubit(
          repositorio: _RepoQuebrado(pr), prontuario: pr, usuario: davi, paciente: maria()),
      act: (c) => c.carregar(),
      expect: () => [
        isA<ExamesLoading>(),
        isA<ExamesError>().having((e) => e.mensagem, 'mensagem', isNotEmpty),
      ],
    );
  });

  group('reação ao repositório', () {
    blocTest<ExamesCubit, ExamesState>(
      'sem ter carregado, mudanças não emitem',
      build: () {
        iniciarAtendimento('3');
        return cubit(davi);
      },
      act: (c) => solicitarBasico(c),
      wait: espera,
      expect: () => <Matcher>[],
    );

    blocTest<ExamesCubit, ExamesState>(
      'solicitar recarrega a lista',
      build: () {
        iniciarAtendimento('3');
        return cubit(davi);
      },
      act: (c) async {
        await c.carregar();
        expect(await solicitarBasico(c), isNull);
      },
      wait: espera,
      expect: () => [
        isA<ExamesLoading>(),
        isA<ExamesSuccess>().having((s) => s.exames, 'exames', isEmpty),
        isA<ExamesSuccess>().having((s) => s.exames.length, 'quantidade', 1),
      ],
    );
  });

  group('ações', () {
    test('sem atendimento em aberto devolve erro e não grava', () async {
      final c = cubit(davi);
      expect(c.temAtendimentoAberto, isFalse);
      expect(await solicitarBasico(c), contains('atendimento'));
      expect(repo.examesDoPaciente('p1'), isEmpty);
      await c.close();
    });

    test('dentista sem vínculo e recepção não têm permissão', () async {
      iniciarAtendimento('10');
      for (final u in [lucia, recepcao]) {
        final c = cubit(u);
        expect(await solicitarBasico(c), contains('permissão'), reason: u.nome);
        await c.close();
      }
      expect(repo.examesDoPaciente('p1'), isEmpty);
    });

    test('fluxo: solicitar, anexar, substituir e avançar status, com logs', () async {
      iniciarAtendimento('3');
      final c = cubit(davi);
      expect(await solicitarBasico(c), isNull);
      final e = repo.examesDoPaciente('p1').single;
      expect(logsAcesso.todos.any((l) => l.acao == 'solicitou_exame' && l.entidadeId == 'p1'), isTrue);

      expect(await c.anexar(e, nomeArquivo: 'pan.jpg', bytes: bytes()), isNull);
      expect(await c.anexar(e, nomeArquivo: 'virus.exe', bytes: bytes()), contains('Formato'));
      final original = repo.arquivosDoExame(e.id).single;

      expect(
        await c.substituir(e, original, nomeArquivo: 'pan2.png', bytes: bytes(), justificativa: ''),
        contains('justificativa'),
      );
      expect(
        await c.substituir(e, original,
            nomeArquivo: 'pan2.png', bytes: bytes(), justificativa: 'Imagem borrada'),
        isNull,
      );
      expect(repo.arquivosDoExame(e.id).length, 2);
      expect(repo.arquivosRetificados('p1'), {original.id});

      expect(await c.mudarStatus(e, StatusExame.realizado), isNull);
      expect(await c.mudarStatus(e, StatusExame.solicitado), contains('Não é possível'));
      await c.close();
    });
  });
}