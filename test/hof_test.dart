import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/core/lote_aplicado.dart';
import 'package:ibn/features/hof/data/hof_repository.dart';
import 'package:ibn/features/hof/domain/hof.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'package:ibn/features/prontuario/domain/prontuario.dart';

final _dia = DateTime(2030, 1, 7, 9);

LoteAplicado lote({DateTime? validade, String numero = 'L123', double qtd = 50}) => LoteAplicado(
      produto: 'Toxina X',
      marca: 'Marca Y',
      lote: numero,
      validade: validade ?? DateTime(2031, 1, 1),
      quantidade: qtd,
    );

PontoAplicacao ponto({double qtd = 4, AreaFace area = AreaFace.testa}) =>
    PontoAplicacao(area: area, lado: LadoFace.bilateral, quantidade: qtd);

ProcedimentoHOF proc({
  String id = 'h1',
  TipoHOF tipo = TipoHOF.toxinaBotulinica,
  String? tipoOutro,
  List<PontoAplicacao>? pontos,
  List<LoteAplicado>? insumos,
  String atendimento = 'a1',
  String prof = '3',
  String paciente = 'p1',
  String? retifica,
  String? justificativa,
  bool anulacao = false,
  DateTime? data,
}) =>
    ProcedimentoHOF(
      id: id,
      pacienteId: paciente,
      atendimentoId: atendimento,
      profissionalId: prof,
      tipo: tipo,
      tipoOutro: tipoOutro,
      pontos: pontos ?? [ponto(), ponto(area: AreaFace.glabela), ponto(area: AreaFace.periorbital)],
      insumos: insumos ?? [lote()],
      dataHora: data ?? _dia,
      retificaId: retifica,
      justificativa: justificativa,
      anulacao: anulacao,
    );

/// Repositório com um atendimento aberto (a1) do profissional 3 com o paciente p1.
({HofRepository hof, ProntuarioRepository pr}) montar() {
  final pr = ProntuarioRepository();
  expect(
    pr.iniciarAtendimento(Atendimento(
      id: 'a1',
      pacienteId: 'p1',
      profissionalId: '3',
      inicio: DateTime(2030, 1, 7, 8),
    )),
    isNull,
  );
  return (hof: HofRepository(prontuario: pr), pr: pr);
}

void main() {
  group('Registro e RN06 (lote e validade)', () {
    test('registra toxina com 3 pontos e lote', () {
      final c = montar();
      expect(c.hof.adicionarProcedimento(proc()), isNull);
      final lista = c.hof.procedimentosDoPaciente('p1');
      expect(lista.length, 1);
      expect(lista.single.pontos.length, 3);
      expect(lista.single.insumos.single.lote, 'L123');
    });

    test('lote vencido é recusado', () {
      final c = montar();
      final erro = c.hof.adicionarProcedimento(
          proc(insumos: [lote(validade: DateTime(2030, 1, 6))]));
      expect(erro, contains('vencido'));
      expect(c.hof.procedimentosDoPaciente('p1'), isEmpty);
    });

    test('validade no próprio dia ainda vale', () {
      final c = montar();
      expect(
          c.hof.adicionarProcedimento(proc(insumos: [lote(validade: DateTime(2030, 1, 7))])),
          isNull);
    });

    test('toxina, preenchimento e bioestimulador exigem lote', () {
      for (final t in [TipoHOF.toxinaBotulinica, TipoHOF.preenchimento, TipoHOF.bioestimulador]) {
        final c = montar();
        final erro = c.hof.adicionarProcedimento(proc(tipo: t, insumos: []));
        expect(erro, contains('RN06'), reason: t.rotulo);
      }
    });

    test('exige número do lote e quantidade', () {
      final c = montar();
      expect(c.hof.adicionarProcedimento(proc(insumos: [lote(numero: ' ')])), contains('lote'));
      expect(c.hof.adicionarProcedimento(proc(insumos: [lote(qtd: 0)])), contains('quantidade'));
    });

    test('fios de sustentação não exigem lote, mas o que for informado é validado', () {
      final c = montar();
      expect(c.hof.adicionarProcedimento(proc(tipo: TipoHOF.fiosSustentacao, insumos: [])), isNull);
      final erro = c.hof.adicionarProcedimento(proc(
        id: 'h2',
        tipo: TipoHOF.fiosSustentacao,
        insumos: [lote(validade: DateTime(2020, 1, 1))],
      ));
      expect(erro, contains('vencido'));
    });

    test('exige ao menos um ponto com quantidade', () {
      final c = montar();
      expect(c.hof.adicionarProcedimento(proc(pontos: [])), contains('ponto'));
      expect(c.hof.adicionarProcedimento(proc(pontos: [ponto(qtd: 0)])), contains('quantidade'));
    });

    test('tipo "outro" exige descrição', () {
      final c = montar();
      expect(c.hof.adicionarProcedimento(proc(tipo: TipoHOF.outro, tipoOutro: ' ')),
          contains('Descreva'));
      expect(
          c.hof.adicionarProcedimento(proc(tipo: TipoHOF.outro, tipoOutro: 'Skinbooster')), isNull);
    });
  });

  group('Atendimento obrigatório', () {
    test('recusa atendimento inexistente', () {
      final c = montar();
      expect(c.hof.adicionarProcedimento(proc(atendimento: 'zzz')), contains('não encontrado'));
    });

    test('recusa atendimento encerrado', () {
      final c = montar();
      c.pr.encerrarAtendimento('a1', '3');
      expect(c.hof.adicionarProcedimento(proc()), contains('encerrado'));
    });

    test('só o profissional do atendimento registra', () {
      final c = montar();
      expect(c.hof.adicionarProcedimento(proc(prof: '10')), contains('profissional do atendimento'));
    });

    test('recusa paciente diferente do atendimento e id duplicado', () {
      final c = montar();
      expect(c.hof.adicionarProcedimento(proc(paciente: 'p2')), contains('Paciente diferente'));
      expect(c.hof.adicionarProcedimento(proc()), isNull);
      expect(c.hof.adicionarProcedimento(proc()), contains('duplicado'));
    });
  });

  group('Retificação e anulação (RN05)', () {
    test('retificar mantém o original e marca como retificado', () {
      final c = montar();
      c.hof.adicionarProcedimento(proc());
      final erro = c.hof.adicionarProcedimento(proc(
        id: 'h2',
        retifica: 'h1',
        justificativa: 'Quantidade errada',
        pontos: [ponto(qtd: 2)],
      ));
      expect(erro, isNull);
      expect(c.hof.procedimentosDoPaciente('p1').map((p) => p.id), ['h2', 'h1']);
      expect(c.hof.retificados('p1'), {'h1'});
    });

    test('exige justificativa e só vale uma vez por registro', () {
      final c = montar();
      c.hof.adicionarProcedimento(proc());
      expect(c.hof.adicionarProcedimento(proc(id: 'h2', retifica: 'h1')), contains('justificativa'));
      expect(c.hof.adicionarProcedimento(proc(id: 'h2', retifica: 'h1', justificativa: 'Motivo A')),
          isNull);
      expect(c.hof.adicionarProcedimento(proc(id: 'h3', retifica: 'h1', justificativa: 'Motivo B')),
          contains('já foi retificado'));
    });

    test('recusa retificar registro inexistente ou de outro autor', () {
      final c = montar();
      c.hof.adicionarProcedimento(proc());
      expect(c.hof.adicionarProcedimento(proc(id: 'h2', retifica: 'x', justificativa: 'abc')),
          contains('não encontrado'));
      c.pr.iniciarAtendimento(Atendimento(
          id: 'a2', pacienteId: 'p1', profissionalId: '10', inicio: DateTime(2030, 1, 7, 8)));
      expect(
        c.hof.adicionarProcedimento(
            proc(id: 'h3', atendimento: 'a2', prof: '10', retifica: 'h1', justificativa: 'abc')),
        contains('autor'),
      );
    });

    test('anular não exige conteúdo novo e deixa o original riscado', () {
      final c = montar();
      c.hof.adicionarProcedimento(proc());
      final erro = c.hof.adicionarProcedimento(proc(
        id: 'h2',
        retifica: 'h1',
        justificativa: 'Paciente errado',
        anulacao: true,
        pontos: [],
        insumos: [],
      ));
      expect(erro, isNull);
      expect(c.hof.retificados('p1'), {'h1'});
      expect(c.hof.procedimentosDoPaciente('p1').length, 2);
    });

    test('anulação precisa apontar um registro e não pode ser retificada', () {
      final c = montar();
      c.hof.adicionarProcedimento(proc());
      expect(c.hof.adicionarProcedimento(proc(id: 'h2', anulacao: true, pontos: [], insumos: [])),
          contains('apontar'));
      c.hof.adicionarProcedimento(proc(
          id: 'h3', retifica: 'h1', justificativa: 'abc', anulacao: true, pontos: [], insumos: []));
      expect(c.hof.adicionarProcedimento(proc(id: 'h4', retifica: 'h3', justificativa: 'abc')),
          contains('anulação'));
    });

    test('retificar vale mesmo com o atendimento encerrado', () {
      final c = montar();
      c.hof.adicionarProcedimento(proc());
      c.pr.encerrarAtendimento('a1', '3');
      expect(
          c.hof.adicionarProcedimento(proc(id: 'h2', retifica: 'h1', justificativa: 'Correção')),
          isNull);
    });

    test('na retificação, a validade do lote é conferida na data do original', () {
      final c = montar();
      c.hof.adicionarProcedimento(proc(insumos: [lote(validade: DateTime(2030, 2, 1))]));
      final erro = c.hof.adicionarProcedimento(proc(
        id: 'h2',
        retifica: 'h1',
        justificativa: 'Correção',
        data: DateTime(2030, 3, 1),
        insumos: [lote(validade: DateTime(2030, 2, 1))],
      ));
      expect(erro, isNull);
    });
  });

  group('Fotos e notificação', () {
    FotoComparativaHOF foto({String desc = 'Antes', Uint8List? bytes}) => FotoComparativaHOF(
          id: 'f1',
          pacienteId: 'p1',
          data: DateTime(2030, 1, 7),
          descricao: desc,
          nomeArquivo: 'a.jpg',
          bytes: bytes ?? Uint8List.fromList([1, 2, 3]),
          profissionalId: '3',
        );

    test('adiciona foto e recusa sem descrição ou vazia', () {
      final c = montar();
      expect(c.hof.adicionarFoto(foto(desc: ' ')), isNotNull);
      expect(c.hof.adicionarFoto(foto(bytes: Uint8List(0))), isNotNull);
      expect(c.hof.adicionarFoto(foto()), isNull);
      expect(c.hof.fotosDoPaciente('p1').length, 1);
      expect(c.hof.temHistorico('p1'), isTrue);
      expect(c.hof.temHistorico('p2'), isFalse);
    });

    test('avisa os ouvintes a cada inclusão', () {
      final c = montar();
      var chamadas = 0;
      c.hof.addListener(() => chamadas++);
      c.hof.adicionarProcedimento(proc());
      c.hof.adicionarFoto(foto());
      c.hof.adicionarProcedimento(proc(pontos: [])); // erro: não notifica
      expect(chamadas, 2);
    });
  });
}