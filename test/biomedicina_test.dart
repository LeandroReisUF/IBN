import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/core/lote_aplicado.dart';
import 'package:ibn/features/biomedicina/data/biomedicina_repository.dart';
import 'package:ibn/features/biomedicina/domain/biomedicina.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'package:ibn/features/prontuario/domain/prontuario.dart';

final _dia = DateTime(2030, 1, 7, 9);

LoteAplicado lote({DateTime? validade, String numero = 'L77', double qtd = 2}) => LoteAplicado(
      produto: 'Ácido mandélico 20%',
      marca: 'Marca Z',
      lote: numero,
      validade: validade ?? DateTime(2031, 1, 1),
      quantidade: qtd,
      unidade: UnidadeInsumo.mililitros,
    );

ProcedimentoEstetico proc({
  String id = 'b1',
  TipoProtocolo protocolo = TipoProtocolo.peeling,
  String? protocoloOutro,
  String regiao = 'Face',
  List<LoteAplicado>? insumos,
  String atendimento = 'a1',
  String prof = '4',
  String paciente = 'p3',
  String? retifica,
  String? justificativa,
  bool anulacao = false,
  DateTime? data,
}) =>
    ProcedimentoEstetico(
      id: id,
      pacienteId: paciente,
      atendimentoId: atendimento,
      profissionalId: prof,
      protocolo: protocolo,
      protocoloOutro: protocoloOutro,
      regiaoTratada: regiao,
      parametros: 'Tempo de contato 5 min',
      insumos: insumos ?? [lote()],
      dataHora: data ?? _dia,
      retificaId: retifica,
      justificativa: justificativa,
      anulacao: anulacao,
    );

/// Atendimento aberto (a1) da Bia (4) com a paciente p3.
({BiomedicinaRepository repo, ProntuarioRepository pr}) montar() {
  final pr = ProntuarioRepository();
  expect(
    pr.iniciarAtendimento(Atendimento(
        id: 'a1', pacienteId: 'p3', profissionalId: '4', inicio: DateTime(2030, 1, 7, 8))),
    isNull,
  );
  return (repo: BiomedicinaRepository(prontuario: pr), pr: pr);
}

void main() {
  group('Registro e RN06 (lote e validade)', () {
    test('registra peeling com lote e validade', () {
      final c = montar();
      expect(c.repo.adicionarProcedimento(proc()), isNull);
      final p = c.repo.procedimentosDoPaciente('p3').single;
      expect(p.rotuloProtocolo, 'Peeling');
      expect(p.insumos.single.lote, 'L77');
      expect(c.repo.temHistorico('p3'), isTrue);
      expect(c.repo.temHistorico('p1'), isFalse);
    });

    test('todo protocolo exige ao menos um produto com lote', () {
      for (final t in TipoProtocolo.values) {
        final c = montar();
        final erro = c.repo.adicionarProcedimento(
            proc(protocolo: t, protocoloOutro: 'Outro protocolo', insumos: []));
        expect(erro, contains('RN06'), reason: t.rotulo);
      }
    });

    test('lote vencido é recusado; a validade vale até o fim do dia', () {
      final c = montar();
      expect(c.repo.adicionarProcedimento(proc(insumos: [lote(validade: DateTime(2030, 1, 6))])),
          contains('vencido'));
      expect(c.repo.procedimentosDoPaciente('p3'), isEmpty);
      expect(c.repo.adicionarProcedimento(proc(insumos: [lote(validade: DateTime(2030, 1, 7))])),
          isNull);
    });

    test('exige número do lote, quantidade, região e descrição do "outro"', () {
      final c = montar();
      expect(c.repo.adicionarProcedimento(proc(insumos: [lote(numero: ' ')])), contains('lote'));
      expect(c.repo.adicionarProcedimento(proc(insumos: [lote(qtd: 0)])), contains('quantidade'));
      expect(c.repo.adicionarProcedimento(proc(regiao: ' ')), contains('região'));
      expect(c.repo.adicionarProcedimento(proc(protocolo: TipoProtocolo.outro, protocoloOutro: ' ')),
          contains('Descreva'));
      expect(
          c.repo.adicionarProcedimento(
              proc(protocolo: TipoProtocolo.outro, protocoloOutro: 'Carboxiterapia')),
          isNull);
    });
  });

  group('Atendimento obrigatório', () {
    test('recusa atendimento inexistente, encerrado, outro profissional e outro paciente', () {
      final c = montar();
      expect(c.repo.adicionarProcedimento(proc(atendimento: 'zzz')), contains('não encontrado'));
      expect(c.repo.adicionarProcedimento(proc(prof: '10')), contains('profissional do atendimento'));
      expect(c.repo.adicionarProcedimento(proc(paciente: 'p1')), contains('Paciente diferente'));
      c.pr.encerrarAtendimento('a1', '4');
      expect(c.repo.adicionarProcedimento(proc()), contains('encerrado'));
    });

    test('recusa id duplicado', () {
      final c = montar();
      expect(c.repo.adicionarProcedimento(proc()), isNull);
      expect(c.repo.adicionarProcedimento(proc()), contains('duplicado'));
    });
  });

  group('Retificação e anulação (RN05)', () {
    test('retificar mantém o original e marca como retificado', () {
      final c = montar();
      c.repo.adicionarProcedimento(proc());
      expect(
        c.repo.adicionarProcedimento(
            proc(id: 'b2', retifica: 'b1', justificativa: 'Região errada', regiao: 'Colo')),
        isNull,
      );
      expect(c.repo.procedimentosDoPaciente('p3').map((p) => p.id), ['b2', 'b1']);
      expect(c.repo.retificados('p3'), {'b1'});
    });

    test('exige justificativa, uma vez por registro e o mesmo autor', () {
      final c = montar();
      c.repo.adicionarProcedimento(proc());
      expect(c.repo.adicionarProcedimento(proc(id: 'b2', retifica: 'b1')), contains('justificativa'));
      expect(c.repo.adicionarProcedimento(proc(id: 'b2', retifica: 'x', justificativa: 'abc')),
          contains('não encontrado'));
      expect(c.repo.adicionarProcedimento(proc(id: 'b2', retifica: 'b1', justificativa: 'Motivo A')),
          isNull);
      expect(c.repo.adicionarProcedimento(proc(id: 'b3', retifica: 'b1', justificativa: 'Motivo B')),
          contains('já foi retificado'));

      c.pr.iniciarAtendimento(Atendimento(
          id: 'a2', pacienteId: 'p3', profissionalId: '10', inicio: DateTime(2030, 1, 8)));
      expect(
        c.repo.adicionarProcedimento(
            proc(id: 'b4', atendimento: 'a2', prof: '10', retifica: 'b2', justificativa: 'abc')),
        contains('autor'),
      );
    });

    test('anular não exige conteúdo novo e a anulação não é retificável', () {
      final c = montar();
      c.repo.adicionarProcedimento(proc());
      expect(c.repo.adicionarProcedimento(proc(id: 'b2', anulacao: true, insumos: [], regiao: '')),
          contains('apontar'));
      expect(
        c.repo.adicionarProcedimento(proc(
            id: 'b2',
            retifica: 'b1',
            justificativa: 'Paciente errado',
            anulacao: true,
            insumos: [],
            regiao: '')),
        isNull,
      );
      expect(c.repo.retificados('p3'), {'b1'});
      expect(c.repo.adicionarProcedimento(proc(id: 'b3', retifica: 'b2', justificativa: 'abc')),
          contains('anulação'));
    });

    test('retificar vale com o atendimento encerrado e confere a validade na data do original', () {
      final c = montar();
      c.repo.adicionarProcedimento(proc(insumos: [lote(validade: DateTime(2030, 2, 1))]));
      c.pr.encerrarAtendimento('a1', '4');
      expect(
        c.repo.adicionarProcedimento(proc(
          id: 'b2',
          retifica: 'b1',
          justificativa: 'Correção',
          data: DateTime(2030, 3, 1),
          insumos: [lote(validade: DateTime(2030, 2, 1))],
        )),
        isNull,
      );
    });

    test('avisa os ouvintes só quando grava', () {
      final c = montar();
      var chamadas = 0;
      c.repo.addListener(() => chamadas++);
      c.repo.adicionarProcedimento(proc());
      c.repo.adicionarProcedimento(proc(id: 'b2', insumos: [])); // erro
      expect(chamadas, 1);
    });
  });
}