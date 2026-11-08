import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/core/pdf_simples.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/auth/domain/usuario.dart';
import 'package:ibn/features/documentos/data/documentos_repository.dart';
import 'package:ibn/features/documentos/domain/documentos.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'package:ibn/features/prontuario/domain/prontuario.dart';

final _dia = DateTime(2030, 1, 7, 9);

DocumentoClinico doc({
  String id = 'd1',
  String conteudo = 'Atesto que Maria esteve em atendimento.',
  String atendimento = 'a1',
  String prof = '3',
  String paciente = 'p1',
  bool assinado = false,
  String? retifica,
  String? justificativa,
}) =>
    DocumentoClinico(
      id: id,
      pacienteId: paciente,
      atendimentoId: atendimento,
      profissionalId: prof,
      tipo: TipoDocumento.atestado,
      titulo: 'Atestado odontológico',
      conteudo: conteudo,
      modeloId: 'atestado',
      modeloVersao: 1,
      emitidoEm: _dia,
      assinado: assinado,
      retificaId: retifica,
      justificativa: justificativa,
    );

({DocumentosRepository docs, ProntuarioRepository pr}) montar() {
  final pr = ProntuarioRepository();
  expect(
    pr.iniciarAtendimento(Atendimento(
        id: 'a1', pacienteId: 'p1', profissionalId: '3', inicio: DateTime(2030, 1, 7, 8))),
    isNull,
  );
  return (docs: DocumentosRepository(prontuario: pr), pr: pr);
}

void main() {
  group('Variáveis e preenchimento', () {
    test('variaveisDoCorpo lista sem repetir e na ordem', () {
      expect(variaveisDoCorpo('{{a}} x {{b}} y {{a}} {{ c }}'), ['a', 'b', 'c']);
    });

    test('variaveisManuais ignora as automáticas', () {
      expect(variaveisManuais('{{paciente_nome}} {{dias_afastamento}} {{data_emissao}}'),
          ['dias_afastamento']);
    });

    test('preencher troca as variáveis e sinaliza as que faltam', () {
      final r = preencherModelo('Olá {{nome}}, {{dias}} dia(s). {{nome}}', {'nome': 'Maria', 'dias': ' '});
      expect(r.faltando, ['dias']);
      expect(r.texto, 'Olá Maria, [dias $marcadorNaoPreenchido] dia(s). Maria');
    });

    test('preencher sem faltas devolve a lista vazia', () {
      final r = preencherModelo('{{a}}', {'a': 'x'});
      expect(r.faltando, isEmpty);
      expect(r.texto, 'x');
    });

    test('valores automáticos: CPF formatado, responsável e registro do conselho', () {
      final paciente = Paciente(
        id: 'p2',
        nome: 'João',
        cpf: '11144477735',
        dataNascimento: DateTime(2014, 6, 20),
        telefone: '81988887777',
        responsavel: const ResponsavelLegal(
            nome: 'Carla', cpf: '39053344705', parentesco: 'Mãe', telefone: '81988887777'),
        termoLgpd: TermoLGPD(aceitoEm: DateTime(2026, 9, 10), versao: versaoTermoLgpd),
      );
      const comRegistro = Usuario(
          id: '3',
          nome: 'Dr. Davi',
          email: 'd@x',
          perfil: Perfil.dentista,
          conselho: 'CRO-PE',
          registroConselho: '12345');
      const semRegistro =
          Usuario(id: '10', nome: 'Dra. Lúcia', email: 'l@x', perfil: Perfil.dentista);

      final v = valoresAutomaticos(paciente: paciente, usuario: comRegistro, agora: DateTime(2030, 1, 7));
      expect(v['paciente_cpf'], '111.444.777-35');
      expect(v['paciente_responsavel'], 'Carla (Mãe)');
      expect(v['data_emissao'], '07/01/2030');
      expect(v['profissional_registro'], 'CRO-PE 12345');
      expect(valoresAutomaticos(paciente: paciente, usuario: semRegistro, agora: _dia)['profissional_registro'],
          '');
    });

    test('todos os modelos padrão têm as variáveis automáticas reconhecidas', () {
      for (final m in modelosPadrao) {
        expect(m.corpo.trim(), isNotEmpty, reason: m.nome);
        final r = preencherModelo(m.corpo, {
          for (final v in variaveisDoCorpo(m.corpo)) v: 'x',
        });
        expect(r.faltando, isEmpty, reason: m.nome);
      }
    });
  });

  group('Documento (RN05)', () {
    test('cria rascunho dentro de um atendimento em aberto', () {
      final c = montar();
      expect(c.docs.adicionarDocumento(doc()), isNull);
      expect(c.docs.documentosDoPaciente('p1').single.assinado, isFalse);
      expect(c.docs.temHistorico('p1'), isTrue);
      expect(c.docs.temHistorico('p2'), isFalse);
    });

    test('recusa vazio, já assinado, duplicado e atendimento inválido', () {
      final c = montar();
      expect(c.docs.adicionarDocumento(doc(conteudo: ' ')), contains('vazio'));
      expect(c.docs.adicionarDocumento(doc(assinado: true)), contains('rascunho'));
      expect(c.docs.adicionarDocumento(doc(atendimento: 'zzz')), contains('não encontrado'));
      expect(c.docs.adicionarDocumento(doc(prof: '10')), contains('profissional do atendimento'));
      expect(c.docs.adicionarDocumento(doc(paciente: 'p2')), contains('Paciente diferente'));
      expect(c.docs.adicionarDocumento(doc()), isNull);
      expect(c.docs.adicionarDocumento(doc()), contains('duplicado'));
    });

    test('recusa atendimento encerrado', () {
      final c = montar();
      c.pr.encerrarAtendimento('a1', '3');
      expect(c.docs.adicionarDocumento(doc()), contains('encerrado'));
    });

    test('rascunho pode ser editado e descartado; só pelo autor', () {
      final c = montar();
      c.docs.adicionarDocumento(doc());
      expect(c.docs.atualizarRascunho('d1', '10', 'Invasor'), contains('autor'));
      expect(c.docs.atualizarRascunho('d1', '3', ' '), contains('vazio'));
      expect(c.docs.atualizarRascunho('d1', '3', ' Texto novo '), isNull);
      expect(c.docs.documentoPorId('d1')!.conteudo, 'Texto novo');
      expect(c.docs.descartarRascunho('d1', '10'), contains('autor'));
      expect(c.docs.descartarRascunho('d1', '3'), isNull);
      expect(c.docs.documentosDoPaciente('p1'), isEmpty);
    });

    test('assinar gera selo e bloqueia edição e exclusão', () {
      final c = montar();
      c.docs.adicionarDocumento(doc());
      expect(c.docs.assinarDocumento('d1', '10'), contains('autor'));
      expect(c.docs.assinarDocumento('d1', '3', agora: DateTime(2030, 1, 7, 10)), isNull);
      final d = c.docs.documentoPorId('d1')!;
      expect(d.assinado, isTrue);
      expect(d.selo, isNotNull);
      expect(d.assinadoEm, DateTime(2030, 1, 7, 10));
      expect(c.docs.atualizarRascunho('d1', '3', 'Tentativa'), contains('RN05'));
      expect(c.docs.descartarRascunho('d1', '3'), contains('RN05'));
      expect(c.docs.assinarDocumento('d1', '3'), contains('já assinado'));
      expect(c.docs.documentoPorId('d1')!.conteudo, 'Atesto que Maria esteve em atendimento.');
    });

    test('não assina com campo não preenchido', () {
      final c = montar();
      c.docs.adicionarDocumento(doc(conteudo: 'Dias: [dias_afastamento $marcadorNaoPreenchido]'));
      expect(c.docs.assinarDocumento('d1', '3'), contains(marcadorNaoPreenchido));
      expect(c.docs.documentoPorId('d1')!.assinado, isFalse);
    });

    test('correção: só de documento assinado, com justificativa, uma vez, mesmo autor', () {
      final c = montar();
      c.docs.adicionarDocumento(doc());
      expect(c.docs.adicionarDocumento(doc(id: 'd2', retifica: 'd1', justificativa: 'Erro')),
          contains('rascunho'));
      c.docs.assinarDocumento('d1', '3');
      expect(c.docs.adicionarDocumento(doc(id: 'd2', retifica: 'd1')), contains('justificativa'));
      expect(c.docs.adicionarDocumento(doc(id: 'd2', retifica: 'x', justificativa: 'Erro')),
          contains('não encontrado'));
      expect(c.docs.adicionarDocumento(doc(id: 'd2', retifica: 'd1', justificativa: 'Erro de data')),
          isNull);
      expect(c.docs.adicionarDocumento(doc(id: 'd3', retifica: 'd1', justificativa: 'Outro')),
          contains('já foi corrigido'));
      expect(c.docs.retificados('p1'), {'d1'});
      expect(c.docs.documentosDoPaciente('p1').length, 2);
    });

    test('correção funciona com o atendimento encerrado e o autor é o mesmo', () {
      final c = montar();
      c.docs.adicionarDocumento(doc());
      c.docs.assinarDocumento('d1', '3');
      c.pr.encerrarAtendimento('a1', '3');
      expect(c.docs.adicionarDocumento(doc(id: 'd2', retifica: 'd1', justificativa: 'Erro de data')),
          isNull);
      c.pr.iniciarAtendimento(Atendimento(
          id: 'a2', pacienteId: 'p1', profissionalId: '10', inicio: DateTime(2030, 1, 8)));
      expect(
        c.docs.adicionarDocumento(
            doc(id: 'd3', atendimento: 'a2', prof: '10', retifica: 'd1', justificativa: 'abc')),
        contains('autor'),
      );
    });

    test('avisa os ouvintes só quando muda', () {
      final c = montar();
      var chamadas = 0;
      c.docs.addListener(() => chamadas++);
      c.docs.adicionarDocumento(doc());
      c.docs.adicionarDocumento(doc(conteudo: '')); // erro
      c.docs.assinarDocumento('d1', '3');
      expect(chamadas, 2);
    });
        test('o atendimento não encerra com rascunho de documento pendente', () {
      final c = montar();
      c.docs.adicionarDocumento(doc());
      expect(c.pr.encerrarAtendimento('a1', '3'), contains('rascunhos de documento'));
      expect(c.pr.atendimentoPorId('a1')!.encerrado, isFalse);
      c.docs.assinarDocumento('d1', '3');
      expect(c.pr.encerrarAtendimento('a1', '3'), isNull);
    });

    test('descartar o rascunho também libera o encerramento', () {
      final c = montar();
      c.docs.adicionarDocumento(doc());
      expect(c.pr.encerrarAtendimento('a1', '3'), isNotNull);
      c.docs.descartarRascunho('d1', '3');
      expect(c.pr.encerrarAtendimento('a1', '3'), isNull);
    });
  });

  group('Modelos', () {
    test('começa com os modelos padrão', () {
      final c = montar();
      expect(c.docs.modelos.length, modelosPadrao.length);
      expect(c.docs.modeloPorId('atestado')!.versao, 1);
    });

    test('editar cria nova versão e mantém o histórico', () {
      final c = montar();
      final base = c.docs.modeloPorId('atestado')!;
      expect(
        c.docs.salvarModelo(ModeloDocumento(
            id: base.id, nome: 'Atestado v2', tipo: base.tipo, corpo: 'Novo texto {{paciente_nome}}')),
        isNull,
      );
      expect(c.docs.modeloPorId('atestado')!.versao, 2);
      expect(c.docs.modeloPorId('atestado')!.nome, 'Atestado v2');
      expect(c.docs.historicoModelo('atestado').map((m) => m.versao), [2, 1]);
      expect(c.docs.modelos.length, modelosPadrao.length);
    });

    test('recusa nome ou texto vazio', () {
      final c = montar();
      const t = TipoDocumento.atestado;
      expect(c.docs.salvarModelo(const ModeloDocumento(id: 'atestado', nome: ' ', tipo: t, corpo: 'x')),
          contains('nome'));
      expect(c.docs.salvarModelo(const ModeloDocumento(id: 'atestado', nome: 'x', tipo: t, corpo: ' ')),
          contains('texto'));
      expect(c.docs.modeloPorId('atestado')!.versao, 1);
    });

    test('documento emitido guarda a versão do modelo e não muda quando o modelo muda', () {
      final c = montar();
      c.docs.adicionarDocumento(doc());
      final base = c.docs.modeloPorId('atestado')!;
      c.docs.salvarModelo(
          ModeloDocumento(id: base.id, nome: base.nome, tipo: base.tipo, corpo: 'Outro texto'));
      final d = c.docs.documentoPorId('d1')!;
      expect(d.modeloVersao, 1);
      expect(d.conteudo, 'Atesto que Maria esteve em atendimento.');
    });
  });

  group('PDF', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('gera um PDF válido, com acentos e várias linhas', () async {
      final bytes = await gerarPdfSimples(
        titulo: 'Atestado odontológico',
        corpo: List.generate(120, (i) => 'Linha $i: ação, coração, órgão.').join('\n'),
        rodape: 'Assinado eletronicamente',
      );
      expect(bytes.length, greaterThan(500));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
      test('gera PDF de um texto longo, sem quebras de linha dentro do parágrafo', () async {
      final bytes = await gerarPdfSimples(
        titulo: 'Declaração',
        corpo: List.generate(60, (i) => 'Frase $i do parágrafo.').join(' '),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
}