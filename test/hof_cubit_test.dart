import 'dart:typed_data';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/core/lote_aplicado.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/hof/data/hof_repository.dart';
import 'package:ibn/features/hof/domain/hof.dart';
import 'package:ibn/features/hof/presentation/cubit/hof_cubit.dart';
import 'package:ibn/features/hof/presentation/cubit/hof_state.dart';
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

PontoAplicacao ponto() =>
    const PontoAplicacao(area: AreaFace.testa, lado: LadoFace.bilateral, quantidade: 4);

LoteAplicado lote({DateTime? validade}) => LoteAplicado(
      produto: 'Toxina X',
      lote: 'L1',
      validade: validade ?? DateTime(2100, 1, 1),
      quantidade: 50,
    );

class _RepoQuebrado extends HofRepository {
  _RepoQuebrado(ProntuarioRepository pr) : super(prontuario: pr);

  @override
  List<ProcedimentoHOF> procedimentosDoPaciente(String pacienteId, {String? profissionalId}) =>
      throw StateError('falhou');
}

void main() {
  late ProntuarioRepository pr;
  late HofRepository repo;
  const espera = Duration(milliseconds: 10);

  setUp(() {
    pr = ProntuarioRepository();
    repo = HofRepository(prontuario: pr);
  });

  HofCubit cubit(Usuario u) =>
      HofCubit(repositorio: repo, prontuario: pr, usuario: u, paciente: maria());

  void iniciarAtendimento(String prof) {
    expect(
      pr.iniciarAtendimento(Atendimento(
        id: 'a-$prof',
        pacienteId: 'p1',
        profissionalId: prof,
        inicio: DateTime.now(),
      )),
      isNull,
    );
  }

  Future<String?> registrarBasico(HofCubit c, {LoteAplicado? l}) => c.registrar(
        tipo: TipoHOF.toxinaBotulinica,
        pontos: [ponto()],
        insumos: [l ?? lote()],
      );

  test('começa em Initial', () async {
    final c = cubit(davi);
    expect(c.state, isA<HofInitial>());
    await c.close();
  });

  group('carregar', () {
    blocTest<HofCubit, HofState>(
      'emite Loading e depois Success vazio',
      build: () => cubit(davi),
      act: (c) => c.carregar(),
      expect: () => [
        isA<HofLoading>(),
        isA<HofSuccess>().having((s) => s.procedimentos, 'procedimentos', isEmpty),
      ],
    );

    blocTest<HofCubit, HofState>(
      'cada dentista vê só os próprios registros (RN03)',
      build: () {
        iniciarAtendimento('3');
        iniciarAtendimento('10');
        repo.adicionarProcedimento(ProcedimentoHOF(
          id: 'h1',
          pacienteId: 'p1',
          atendimentoId: 'a-3',
          profissionalId: '3',
          tipo: TipoHOF.toxinaBotulinica,
          pontos: [ponto()],
          insumos: [lote()],
          dataHora: DateTime.now(),
        ));
        repo.adicionarProcedimento(ProcedimentoHOF(
          id: 'h2',
          pacienteId: 'p1',
          atendimentoId: 'a-10',
          profissionalId: '10',
          tipo: TipoHOF.toxinaBotulinica,
          pontos: [ponto()],
          insumos: [lote()],
          dataHora: DateTime.now(),
        ));
        return cubit(davi);
      },
      act: (c) => c.carregar(),
      expect: () => [
        isA<HofLoading>(),
        isA<HofSuccess>().having((s) => s.procedimentos.map((p) => p.id).toList(), 'ids', ['h1']),
      ],
    );

    blocTest<HofCubit, HofState>(
      'falha ao listar emite Error',
      build: () => HofCubit(
          repositorio: _RepoQuebrado(pr), prontuario: pr, usuario: davi, paciente: maria()),
      act: (c) => c.carregar(),
      expect: () => [
        isA<HofLoading>(),
        isA<HofError>().having((e) => e.mensagem, 'mensagem', isNotEmpty),
      ],
    );
  });

  group('reação ao repositório', () {
    blocTest<HofCubit, HofState>(
      'sem ter carregado, mudanças no repositório não emitem',
      build: () {
        iniciarAtendimento('3');
        return cubit(davi);
      },
      act: (c) => registrarBasico(c),
      wait: espera,
      expect: () => <Matcher>[],
    );

    blocTest<HofCubit, HofState>(
      'registrar recarrega a lista',
      build: () {
        iniciarAtendimento('3');
        return cubit(davi);
      },
      act: (c) async {
        await c.carregar();
        expect(await registrarBasico(c), isNull);
      },
      wait: espera,
      expect: () => [
        isA<HofLoading>(),
        isA<HofSuccess>().having((s) => s.procedimentos, 'procedimentos', isEmpty),
        isA<HofSuccess>().having((s) => s.procedimentos.length, 'quantidade', 1),
      ],
    );
  });

  group('ações', () {
    test('sem atendimento em aberto devolve erro e não grava', () async {
      final c = cubit(davi);
      expect(c.temAtendimentoAberto, isFalse);
      final erro = await registrarBasico(c);
      expect(erro, contains('atendimento'));
      expect(repo.procedimentosDoPaciente('p1'), isEmpty);
      await c.close();
    });

    test('dentista sem vínculo e recepção não têm permissão', () async {
      iniciarAtendimento('10');
      for (final u in [lucia, recepcao]) {
        final c = cubit(u);
        expect(await registrarBasico(c), contains('permissão'), reason: u.nome);
        await c.close();
      }
      expect(repo.procedimentosDoPaciente('p1'), isEmpty);
    });

    test('lote vencido é recusado e a mensagem chega à tela', () async {
      iniciarAtendimento('3');
      final c = cubit(davi);
      final erro = await registrarBasico(c, l: lote(validade: DateTime(2020, 1, 1)));
      expect(erro, contains('vencido'));
      expect(repo.procedimentosDoPaciente('p1'), isEmpty);
      await c.close();
    });

    test('registrar gera log; retificar e anular mantêm o histórico', () async {
      iniciarAtendimento('3');
      final c = cubit(davi);
      expect(await registrarBasico(c), isNull);
      final original = repo.procedimentosDoPaciente('p1').single;
      expect(logsAcesso.todos.any((l) => l.acao == 'registrou_hof' && l.entidadeId == 'p1'), isTrue);

      final erroSemMotivo = await c.retificar(original,
          tipo: TipoHOF.toxinaBotulinica,
          pontos: [ponto()],
          insumos: [lote()],
          justificativa: '');
      expect(erroSemMotivo, contains('justificativa'));

      expect(
        await c.retificar(original,
            tipo: TipoHOF.toxinaBotulinica,
            pontos: [ponto()],
            insumos: [lote()],
            justificativa: 'Quantidade errada'),
        isNull,
      );
      final corrigido = repo.procedimentosDoPaciente('p1').first;
      expect(await c.anular(corrigido, 'Paciente errado'), isNull);

      expect(repo.procedimentosDoPaciente('p1').length, 3);
      expect(repo.retificados('p1'), {original.id, corrigido.id});
      await c.close();
    });

    test('adicionarFoto valida e gera log', () async {
      final c = cubit(davi);
      expect(
        await c.adicionarFoto(
            descricao: ' ', isAntes: true, nomeArquivo: 'a.jpg', bytes: Uint8List.fromList([1])),
        isNotNull,
      );
      expect(
        await c.adicionarFoto(
            descricao: 'Antes', isAntes: true, nomeArquivo: 'a.jpg', bytes: Uint8List.fromList([1])),
        isNull,
      );
      expect(repo.fotosDoPaciente('p1').length, 1);
      expect(logsAcesso.todos.any((l) => l.acao == 'adicionou_foto_hof'), isTrue);
      await c.close();
    });
  });

  test('depois de fechado, mudanças no repositório não causam erro', () async {
    iniciarAtendimento('3');
    final c = cubit(davi);
    await c.carregar();
    await c.close();
    expect(() => repo.adicionarFoto(FotoComparativaHOF(
          id: 'f',
          pacienteId: 'p1',
          data: DateTime.now(),
          descricao: 'x',
          nomeArquivo: 'x.jpg',
          bytes: Uint8List.fromList([1]),
          profissionalId: '3',
        )), returnsNormally);
    await Future<void>.delayed(espera);
    expect(c.isClosed, isTrue);
  });
}