import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/core/lote_aplicado.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/biomedicina/data/biomedicina_repository.dart';
import 'package:ibn/features/biomedicina/domain/biomedicina.dart';
import 'package:ibn/features/biomedicina/presentation/cubit/biomedicina_cubit.dart';
import 'package:ibn/features/biomedicina/presentation/cubit/biomedicina_state.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'package:ibn/features/prontuario/domain/prontuario.dart';

const bia = Usuario(id: '4', nome: 'Bia Biomédica', email: 'biomedico@clinica.local', perfil: Perfil.biomedico);
const davi = Usuario(id: '3', nome: 'Dr. Davi', email: 'dentista@clinica.local', perfil: Perfil.dentista);
const recepcao = Usuario(id: '2', nome: 'Rita', email: 'recepcao@clinica.local', perfil: Perfil.recepcionista);

/// Paciente vinculada à Bia (4), ao psicólogo (9) e ao Dr. Davi (3).
Paciente ana({Set<String> vinculos = const {'4', '9', '3'}}) => Paciente(
      id: 'p3',
      nome: 'Ana Beatriz',
      cpf: '12345678909',
      dataNascimento: DateTime(1992, 11, 2),
      telefone: '81991112222',
      termoLgpd: TermoLGPD(aceitoEm: DateTime(2026, 8, 15), versao: versaoTermoLgpd),
      profissionaisVinculados: vinculos,
    );

LoteAplicado lote({DateTime? validade}) => LoteAplicado(
      produto: 'Ácido mandélico 20%',
      lote: 'L77',
      validade: validade ?? DateTime(2100, 1, 1),
      quantidade: 2,
      unidade: UnidadeInsumo.mililitros,
    );

class _RepoQuebrado extends BiomedicinaRepository {
  _RepoQuebrado(ProntuarioRepository pr) : super(prontuario: pr);

  @override
  List<ProcedimentoEstetico> procedimentosDoPaciente(String pacienteId, {String? profissionalId}) =>
      throw StateError('falhou');
}

void main() {
  late ProntuarioRepository pr;
  late BiomedicinaRepository repo;
  const espera = Duration(milliseconds: 10);

  setUp(() {
    pr = ProntuarioRepository();
    repo = BiomedicinaRepository(prontuario: pr);
  });

  BiomedicinaCubit cubit(Usuario u, {Paciente? paciente}) => BiomedicinaCubit(
      repositorio: repo, prontuario: pr, usuario: u, paciente: paciente ?? ana());

  void iniciarAtendimento(String prof, {String id = 'a-x'}) {
    expect(
      pr.iniciarAtendimento(Atendimento(
          id: '$id$prof', pacienteId: 'p3', profissionalId: prof, inicio: DateTime.now())),
      isNull,
    );
  }

  Future<String?> registrarBasico(BiomedicinaCubit c, {LoteAplicado? l}) => c.registrar(
        protocolo: TipoProtocolo.peeling,
        regiaoTratada: 'Face',
        insumos: [l ?? lote()],
      );

  test('começa em Initial', () async {
    final c = cubit(bia);
    expect(c.state, isA<BiomedicinaInitial>());
    await c.close();
  });

  group('carregar', () {
    blocTest<BiomedicinaCubit, BiomedicinaState>(
      'emite Loading e depois Success vazio',
      build: () => cubit(bia),
      act: (c) => c.carregar(),
      expect: () => [
        isA<BiomedicinaLoading>(),
        isA<BiomedicinaSuccess>().having((s) => s.procedimentos, 'procedimentos', isEmpty),
      ],
    );

    blocTest<BiomedicinaCubit, BiomedicinaState>(
      'falha ao listar emite Error',
      build: () => BiomedicinaCubit(
          repositorio: _RepoQuebrado(pr), prontuario: pr, usuario: bia, paciente: ana()),
      act: (c) => c.carregar(),
      expect: () => [
        isA<BiomedicinaLoading>(),
        isA<BiomedicinaError>().having((e) => e.mensagem, 'mensagem', isNotEmpty),
      ],
    );

    blocTest<BiomedicinaCubit, BiomedicinaState>(
      'recarrega sozinho quando um procedimento é registrado',
      build: () {
        iniciarAtendimento('4');
        return cubit(bia);
      },
      act: (c) async {
        await c.carregar();
        expect(await registrarBasico(c), isNull);
      },
      wait: espera,
      expect: () => [
        isA<BiomedicinaLoading>(),
        isA<BiomedicinaSuccess>().having((s) => s.procedimentos, 'procedimentos', isEmpty),
        isA<BiomedicinaSuccess>().having((s) => s.procedimentos.length, 'quantidade', 1),
      ],
    );

    blocTest<BiomedicinaCubit, BiomedicinaState>(
      'cada biomédico vê só os próprios registros (RN03)',
      build: () {
        iniciarAtendimento('4');
        iniciarAtendimento('11'); // outro biomédico, só para o teste
        for (final (id, prof) in [('b1', '4'), ('b2', '11')]) {
          repo.adicionarProcedimento(ProcedimentoEstetico(
            id: id,
            pacienteId: 'p3',
            atendimentoId: 'a-x$prof',
            profissionalId: prof,
            protocolo: TipoProtocolo.peeling,
            regiaoTratada: 'Face',
            insumos: [lote()],
            dataHora: DateTime.now(),
          ));
        }
        return cubit(bia);
      },
      act: (c) => c.carregar(),
      expect: () => [
        isA<BiomedicinaLoading>(),
        isA<BiomedicinaSuccess>().having((s) => s.procedimentos.map((p) => p.id).toList(), 'ids', ['b1']),
      ],
    );
  });

  group('ações', () {
    test('só biomédico vinculado: dentista, recepção e sem vínculo não têm permissão', () async {
      iniciarAtendimento('4');
      iniciarAtendimento('3');
      final casos = <(Usuario, Paciente)>[
        (davi, ana()), // dentista vinculado, mas não é biomédico
        (recepcao, ana()),
        (bia, ana(vinculos: {'9'})), // biomédica sem vínculo
      ];
      for (final (u, p) in casos) {
        final c = cubit(u, paciente: p);
        expect(await registrarBasico(c), contains('permissão'), reason: u.nome);
        await c.close();
      }
      expect(repo.procedimentosDoPaciente('p3'), isEmpty);
    });

    test('sem atendimento em aberto devolve erro e não grava', () async {
      final c = cubit(bia);
      expect(c.temAtendimentoAberto, isFalse);
      expect(await registrarBasico(c), contains('atendimento'));
      expect(repo.procedimentosDoPaciente('p3'), isEmpty);
      await c.close();
    });

    test('lote vencido e procedimento sem produto são recusados', () async {
      iniciarAtendimento('4');
      final c = cubit(bia);
      expect(await registrarBasico(c, l: lote(validade: DateTime(2020, 1, 1))), contains('vencido'));
      expect(
        await c.registrar(protocolo: TipoProtocolo.microagulhamento, regiaoTratada: 'Face', insumos: []),
        contains('RN06'),
      );
      expect(repo.procedimentosDoPaciente('p3'), isEmpty);
      await c.close();
    });

    test('registrar, retificar e anular mantêm o histórico e geram logs', () async {
      iniciarAtendimento('4');
      final c = cubit(bia);
      expect(await registrarBasico(c), isNull);
      final original = repo.procedimentosDoPaciente('p3').single;
      expect(
          logsAcesso.todos.any((l) => l.acao == 'registrou_procedimento_estetico' && l.entidadeId == 'p3'),
          isTrue);

      expect(
        await c.retificar(original,
            protocolo: TipoProtocolo.peeling,
            regiaoTratada: 'Colo',
            insumos: [lote()],
            justificativa: ''),
        contains('justificativa'),
      );
      expect(
        await c.retificar(original,
            protocolo: TipoProtocolo.peeling,
            regiaoTratada: 'Colo',
            insumos: [lote()],
            justificativa: 'Região errada'),
        isNull,
      );
      final corrigido = repo.procedimentosDoPaciente('p3').first;
      expect(corrigido.regiaoTratada, 'Colo');
      expect(await c.anular(corrigido, 'Paciente errado'), isNull);

      expect(repo.procedimentosDoPaciente('p3').length, 3);
      expect(repo.retificados('p3'), {original.id, corrigido.id});
      expect(logsAcesso.todos.any((l) => l.acao == 'retificou_procedimento_estetico'), isTrue);
      expect(logsAcesso.todos.any((l) => l.acao == 'anulou_procedimento_estetico'), isTrue);
      await c.close();
    });
  });

  test('depois de fechado, mudanças no repositório não causam erro', () async {
    iniciarAtendimento('4');
    final c = cubit(bia);
    await c.carregar();
    await c.close();
    expect(() => repo.adicionarProcedimento(ProcedimentoEstetico(
          id: 'x',
          pacienteId: 'p3',
          atendimentoId: 'a-x4',
          profissionalId: '4',
          protocolo: TipoProtocolo.peeling,
          regiaoTratada: 'Face',
          insumos: [lote()],
          dataHora: DateTime.now(),
        )), returnsNormally);
    await Future<void>.delayed(espera);
    expect(c.isClosed, isTrue);
  });
}