import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/core/log_acesso.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/exames/data/exames_repository.dart';
import 'package:ibn/features/exames/data/resultados_lab_repository.dart';
import 'package:ibn/features/exames/domain/exames.dart';
import 'package:ibn/features/exames/domain/resultado_exame.dart';
import 'package:ibn/features/exames/presentation/cubit/resultados_lab_cubit.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'package:ibn/features/prontuario/domain/prontuario.dart';

const bia = Usuario(id: '4', nome: 'Bia Biomédica', email: 'biomedico@clinica.local', perfil: Perfil.biomedico);
const recepcao = Usuario(id: '2', nome: 'Rita', email: 'recepcao@clinica.local', perfil: Perfil.recepcionista);

Paciente ana({Set<String> vinculos = const {'4', '9'}}) => Paciente(
      id: 'p3',
      nome: 'Ana Beatriz',
      cpf: '12345678909',
      dataNascimento: DateTime(1992, 11, 2),
      telefone: '81991112222',
      termoLgpd: TermoLGPD(aceitoEm: DateTime(2026, 8, 15), versao: versaoTermoLgpd),
      profissionaisVinculados: vinculos,
    );

/// Hemoglobina de referência 12 a 16 g/dL.
ResultadoLab hb(double valor) =>
    ResultadoLab(analito: 'Hemoglobina', valor: valor, unidade: 'g/dL', refMin: 12, refMax: 16);

ResultadoExame resultado({
  String id = 'r1',
  String exame = 'e1',
  String prof = '4',
  String paciente = 'p3',
  ResultadoLab? dados,
  String? retifica,
  String? justificativa,
}) =>
    ResultadoExame(
      id: id,
      exameId: exame,
      pacienteId: paciente,
      dados: dados ?? hb(13),
      profissionalId: prof,
      registradoEm: DateTime(2030, 1, 7, 10),
      retificaId: retifica,
      justificativa: justificativa,
    );

class _Contexto {
  final ProntuarioRepository pr = ProntuarioRepository();
  late final ExamesRepository exames = ExamesRepository(prontuario: pr);
  late final ResultadosLabRepository lab = ResultadosLabRepository(exames: exames);

  /// Atendimento aberto (a1) da Bia com a Ana e o exame laboratorial e1.
  _Contexto() {
    expect(
      pr.iniciarAtendimento(Atendimento(
          id: 'a1', pacienteId: 'p3', profissionalId: '4', inicio: DateTime(2030, 1, 7, 8))),
      isNull,
    );
    expect(
      exames.solicitarExame(Exame(
        id: 'e1',
        pacienteId: 'p3',
        atendimentoId: 'a1',
        profissionalId: '4',
        tipo: TipoExame.laboratorial,
        nome: 'Hemograma completo',
        solicitadoEm: DateTime(2030, 1, 7, 9),
        atualizadoEm: DateTime(2030, 1, 7, 9),
      )),
      isNull,
    );
  }
}

void main() {
  group('Repositório', () {
    test('lança resultados e só os fora do padrão viram alerta', () {
      final c = _Contexto();
      expect(c.lab.adicionarResultado(resultado(dados: hb(13))), isNull); // dentro
      expect(c.lab.adicionarResultado(resultado(id: 'r2', dados: hb(18.5))), isNull); // alto
      expect(c.lab.adicionarResultado(resultado(id: 'r3', dados: hb(9))), isNull); // baixo
      expect(c.lab.resultadosDoExame('e1').map((r) => r.id), ['r1', 'r2', 'r3']);
      expect(c.lab.alertasDoExame('e1').map((r) => r.id), ['r2', 'r3']);
    });

    test('valida analito, unidade, valor e referência', () {
      final c = _Contexto();
      const base = ResultadoLab(analito: 'Hb', valor: 1, unidade: 'g/dL');
      ResultadoLab com({String? analito, String? unidade, double? valor, double? min, double? max}) =>
          ResultadoLab(
            analito: analito ?? base.analito,
            valor: valor ?? base.valor,
            unidade: unidade ?? base.unidade,
            refMin: min,
            refMax: max,
          );

      expect(c.lab.adicionarResultado(resultado(dados: com(analito: ' '))), contains('analito'));
      expect(c.lab.adicionarResultado(resultado(dados: com(unidade: ' '))), contains('unidade'));
      expect(c.lab.adicionarResultado(resultado(dados: com(valor: double.nan))), contains('inválido'));
      expect(c.lab.adicionarResultado(resultado(dados: com(valor: double.infinity))), contains('inválido'));
      expect(c.lab.adicionarResultado(resultado(dados: com(min: 10, max: 5))), contains('mínima'));
      expect(c.lab.adicionarResultado(resultado(dados: com(min: 5, valor: 6))), isNull); // só mínima
      expect(c.lab.adicionarResultado(resultado(id: 'r2', dados: com(max: 5, valor: 9))), isNull);
      expect(c.lab.alertasDoExame('e1').map((r) => r.id), ['r2']); // 9 > máx. 5
    });

    test('só quem solicitou lança; exame inexistente, de outro paciente ou cancelado é recusado', () {
      final c = _Contexto();
      expect(c.lab.adicionarResultado(resultado(prof: '10')), contains('Só quem solicitou'));
      expect(c.lab.adicionarResultado(resultado(exame: 'zzz')), contains('não encontrado'));
      expect(c.lab.adicionarResultado(resultado(paciente: 'p1')), contains('Paciente diferente'));
      c.exames.mudarStatus('e1', '4', StatusExame.cancelado);
      expect(c.lab.adicionarResultado(resultado()), contains('cancelado'));
      expect(c.lab.resultadosDoExame('e1'), isEmpty);
    });

    test('o resultado pode chegar depois do atendimento encerrado', () {
      final c = _Contexto();
      c.pr.encerrarAtendimento('a1', '4');
      expect(c.lab.adicionarResultado(resultado()), isNull);
    });

    test('corrigir mantém o original, riscado, e o alerta passa a valer só para o novo (RN05)', () {
      final c = _Contexto();
      c.lab.adicionarResultado(resultado(dados: hb(18.5))); // alto
      expect(c.lab.alertasDoExame('e1').length, 1);

      expect(c.lab.adicionarResultado(resultado(id: 'r2', retifica: 'r1', dados: hb(13.5))),
          contains('justificativa'));
      expect(
        c.lab.adicionarResultado(
            resultado(id: 'r2', retifica: 'r1', dados: hb(13.5), justificativa: 'Digitei errado')),
        isNull,
      );
      expect(c.lab.resultadosDoExame('e1').length, 2); // nada é apagado
      expect(c.lab.substituidos('e1'), {'r1'});
      expect(c.lab.alertasDoExame('e1'), isEmpty); // o alto foi substituído por um normal
    });

    test('correção: resultado existente, do mesmo exame e uma única vez', () {
      final c = _Contexto();
      c.lab.adicionarResultado(resultado());
      expect(c.lab.adicionarResultado(resultado(id: 'r2', retifica: 'x', justificativa: 'abc')),
          contains('não encontrado'));
      expect(c.lab.adicionarResultado(resultado(id: 'r2', retifica: 'r1', justificativa: 'abc')), isNull);
      expect(c.lab.adicionarResultado(resultado(id: 'r3', retifica: 'r1', justificativa: 'abc')),
          contains('já foi corrigido'));
      expect(c.lab.adicionarResultado(resultado(id: 'r2')), contains('duplicado'));
    });

    test('avisa os ouvintes só quando grava', () {
      final c = _Contexto();
      var chamadas = 0;
      c.lab.addListener(() => chamadas++);
      c.lab.adicionarResultado(resultado());
      c.lab.adicionarResultado(resultado(id: 'r2', dados: const ResultadoLab(analito: ' ', valor: 1, unidade: 'u')));
      expect(chamadas, 1);
    });
  });

  group('Cubit', () {
    late _Contexto c;
    const espera = Duration(milliseconds: 10);

    setUp(() => c = _Contexto());

    ResultadosLabCubit cubit(Usuario u, {Paciente? paciente}) => ResultadosLabCubit(
          repositorio: c.lab,
          usuario: u,
          paciente: paciente ?? ana(),
          exame: c.exames.examePorId('e1')!,
        );

    test('começa em Initial', () async {
      final x = cubit(bia);
      expect(x.state, isA<ResultadosLabInitial>());
      await x.close();
    });

    blocTest<ResultadosLabCubit, ResultadosLabState>(
      'hemograma com valor alto: o alerta aparece no estado',
      build: () => cubit(bia),
      act: (x) async {
        await x.carregar();
        expect(
          await x.registrar(const ResultadoLab(
              analito: 'Hemoglobina', valor: 18.5, unidade: 'g/dL', refMin: 12, refMax: 16)),
          isNull,
        );
        expect(
          await x.registrar(const ResultadoLab(
              analito: 'Leucócitos', valor: 7000, unidade: '/mm³', refMin: 4000, refMax: 11000)),
          isNull,
        );
      },
      wait: espera,
      expect: () => [
        isA<ResultadosLabLoading>(),
        isA<ResultadosLabSuccess>().having((s) => s.resultados, 'resultados', isEmpty),
        isA<ResultadosLabSuccess>()
            .having((s) => s.resultados.length, 'resultados', 1)
            .having((s) => s.alertas.length, 'alertas', 1),
        isA<ResultadosLabSuccess>()
            .having((s) => s.resultados.length, 'resultados', 2)
            .having((s) => s.alertas.map((r) => r.dados.analito).toList(), 'alertas', ['Hemoglobina']),
      ],
    );

    test('sem vínculo e recepção não têm permissão', () async {
      for (final (u, p) in <(Usuario, Paciente)>[
        (bia, ana(vinculos: {'9'})),
        (recepcao, ana()),
      ]) {
        final x = cubit(u, paciente: p);
        expect(await x.registrar(hb(13)), contains('permissão'), reason: u.nome);
        await x.close();
      }
      expect(c.lab.resultadosDoExame('e1'), isEmpty);
    });

    test('corrigir gera log e tira o alerta do original', () async {
      final x = cubit(bia);
      await x.carregar();
      expect(await x.registrar(hb(18.5)), isNull);
      final original = (x.state as ResultadosLabSuccess).resultados.single;
      expect(logsAcesso.todos.any((l) => l.acao == 'lancou_resultado_exame' && l.entidadeId == 'p3'), isTrue);

      expect(await x.registrar(hb(13), anterior: original, justificativa: ''), contains('justificativa'));
      expect(await x.registrar(hb(13), anterior: original, justificativa: 'Digitei errado'), isNull);
      await Future<void>.delayed(espera);

      final estado = x.state as ResultadosLabSuccess;
      expect(estado.resultados.length, 2);
      expect(estado.substituidos, {original.id});
      expect(estado.alertas, isEmpty);
      expect(logsAcesso.todos.any((l) => l.acao == 'corrigiu_resultado_exame'), isTrue);
      await x.close();
    });
  });
}