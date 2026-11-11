import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/core/especialidade.dart';
import 'package:ibn/features/anamnese/data/anamnese_repository.dart';
import 'package:ibn/features/anamnese/domain/anamnese.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'package:ibn/features/prontuario/domain/prontuario.dart';

const _perguntas = [
  PerguntaAnamnese(id: 'queixa', enunciado: 'Queixa', tipo: TipoResposta.textoLongo, obrigatoria: true),
  PerguntaAnamnese(id: 'gestante', enunciado: 'Gestante?', tipo: TipoResposta.simNao, obrigatoria: true),
  PerguntaAnamnese(
      id: 'esc', enunciado: 'Escovação', tipo: TipoResposta.escolhaUnica, opcoes: ['1 vez', '2 vezes']),
  PerguntaAnamnese(
      id: 'alergias',
      enunciado: 'Alergias',
      tipo: TipoResposta.multiplaEscolha,
      opcoes: ['Penicilina', 'Látex']),
  PerguntaAnamnese(id: 'dor', enunciado: 'Dor', tipo: TipoResposta.escala),
  PerguntaAnamnese(id: 'ultima', enunciado: 'Última consulta', tipo: TipoResposta.data),
];

const _modeloTeste = ModeloAnamnese(
  id: 'm-teste',
  nome: 'Modelo de teste',
  especialidade: Especialidade.odontologia,
  perguntas: _perguntas,
);

Anamnese anamnese({
  String id = 'an1',
  Map<String, String>? respostas,
  String? atendimento,
  String prof = '3',
  String paciente = 'p1',
  String modelo = 'm-teste',
  String? anterior,
  bool assinada = false,
}) =>
    Anamnese(
      id: id,
      pacienteId: paciente,
      atendimentoId: atendimento,
      profissionalId: prof,
      modeloId: modelo,
      titulo: 'Modelo de teste',
      modeloVersao: 1,
      perguntas: _perguntas,
      respostas: respostas ?? {'queixa': 'Dor no 26', 'gestante': 'nao'},
      criadaEm: DateTime(2030, 1, 7),
      anteriorId: anterior,
      assinada: assinada,
    );

({AnamneseRepository repo, ProntuarioRepository pr}) montar() {
  final pr = ProntuarioRepository();
  return (repo: AnamneseRepository(prontuario: pr, modelos: const [_modeloTeste]), pr: pr);
}

void main() {
  group('Respostas', () {
    test('múltipla escolha: juntar e separar', () {
      expect(juntarMultipla(['A', 'B']), 'A|B');
      expect(separarMultipla('A|B'), ['A', 'B']);
      expect(separarMultipla(''), isEmpty);
    });

    test('faltandoObrigatorias lista os enunciados das obrigatórias sem resposta', () {
      expect(faltandoObrigatorias(_perguntas, {}), ['Queixa', 'Gestante?']);
      expect(faltandoObrigatorias(_perguntas, {'queixa': ' ', 'gestante': 'sim'}), ['Queixa']);
      expect(faltandoObrigatorias(_perguntas, {'queixa': 'x', 'gestante': 'sim'}), isEmpty);
    });

    test('validarRespostas aceita formatos corretos e ignora vazias', () {
      expect(
        validarRespostas(_perguntas, {
          'queixa': 'texto',
          'gestante': 'sim',
          'esc': '2 vezes',
          'alergias': 'Penicilina|Látex',
          'dor': '7',
          'ultima': '2029-12-31',
        }),
        isNull,
      );
      expect(validarRespostas(_perguntas, {'dor': '', 'esc': ' '}), isNull);
    });

    test('validarRespostas recusa formatos inválidos e pergunta desconhecida', () {
      expect(validarRespostas(_perguntas, {'gestante': 'talvez'}), contains('Gestante?'));
      expect(validarRespostas(_perguntas, {'esc': '5 vezes'}), contains('Escovação'));
      expect(validarRespostas(_perguntas, {'alergias': 'Penicilina|Poeira'}), contains('Alergias'));
      expect(validarRespostas(_perguntas, {'dor': '11'}), contains('Dor'));
      expect(validarRespostas(_perguntas, {'dor': 'abc'}), contains('Dor'));
      expect(validarRespostas(_perguntas, {'ultima': 'ontem'}), contains('Última consulta'));
      expect(validarRespostas(_perguntas, {'zzz': 'x'}), contains('desconhecida'));
    });

    test('respostaLegivel formata cada tipo', () {
      expect(respostaLegivel(_perguntas[1], 'sim'), 'Sim');
      expect(respostaLegivel(_perguntas[1], 'nao'), 'Não');
      expect(respostaLegivel(_perguntas[3], 'Penicilina|Látex'), 'Penicilina, Látex');
      expect(respostaLegivel(_perguntas[4], '7'), '7/10');
      expect(respostaLegivel(_perguntas[5], '2029-12-31'), '31/12/2029');
      expect(respostaLegivel(_perguntas[0], '  '), isNull);
      expect(respostaLegivel(_perguntas[0], null), isNull);
    });

    test('modelos padrão são consistentes (ids únicos, opções e obrigatórias)', () {
      for (final m in modelosAnamnesePadrao) {
        final ids = m.perguntas.map((p) => p.id).toList();
        expect(ids.toSet().length, ids.length, reason: m.nome);
        if (m.id != 'anamnese-odontologica') {
          expect(m.perguntas.any((p) => p.obrigatoria), isTrue, reason: m.nome);
        }
        for (final p in m.perguntas) {
          final comOpcoes =
              p.tipo == TipoResposta.escolhaUnica || p.tipo == TipoResposta.multiplaEscolha;
          expect(p.opcoes.isNotEmpty, comOpcoes, reason: '${m.nome} / ${p.id}');
          expect(p.opcoes.any((o) => o.contains('|')), isFalse, reason: '${m.nome} / ${p.id}');
        }
      }
      final fototipo = modelosAnamnesePadrao
          .firstWhere((m) => m.id == 'anamnese-estetica')
          .perguntas
          .firstWhere((p) => p.id == 'fototipo');
      expect(fototipo.opcoes.length, 6); // Fitzpatrick I a VI
    });
  });

  group('Anamnese (RN05)', () {
    test('cria rascunho, com ou sem atendimento', () {
      final c = montar();
      expect(c.repo.adicionarAnamnese(anamnese()), isNull);
      expect(c.repo.anamnesesDoPaciente('p1').single.assinada, isFalse);
      expect(c.repo.temHistorico('p1'), isTrue);
      expect(c.repo.temHistorico('p2'), isFalse);
    });

    test('recusa duplicada, já assinada, sem perguntas e respostas inválidas', () {
      final c = montar();
      expect(c.repo.adicionarAnamnese(anamnese(assinada: true)), contains('rascunho'));
      expect(c.repo.adicionarAnamnese(anamnese(respostas: {'gestante': 'talvez'})), contains('Gestante?'));
      expect(c.repo.adicionarAnamnese(anamnese()), isNull);
      expect(c.repo.adicionarAnamnese(anamnese()), contains('duplicada'));
    });

    test('valida o atendimento quando informado', () {
      final c = montar();
      expect(c.repo.adicionarAnamnese(anamnese(atendimento: 'zzz')), contains('não encontrado'));
      c.pr.iniciarAtendimento(Atendimento(
          id: 'a1', pacienteId: 'p1', profissionalId: '3', inicio: DateTime(2030, 1, 7, 8)));
      expect(c.repo.adicionarAnamnese(anamnese(atendimento: 'a1', paciente: 'p2')),
          contains('Paciente diferente'));
      expect(c.repo.adicionarAnamnese(anamnese(atendimento: 'a1', prof: '10')),
          contains('profissional do atendimento'));
      expect(c.repo.adicionarAnamnese(anamnese(atendimento: 'a1')), isNull);
    });

    test('só um rascunho por paciente, autor e modelo', () {
      final c = montar();
      c.repo.adicionarAnamnese(anamnese());
      expect(c.repo.adicionarAnamnese(anamnese(id: 'an2')), contains('rascunho desta anamnese'));
      expect(c.repo.adicionarAnamnese(anamnese(id: 'an3', prof: '10')), isNull);
    });

    test('rascunho pode ser editado e descartado, só pelo autor', () {
      final c = montar();
      c.repo.adicionarAnamnese(anamnese());
      expect(c.repo.atualizarRascunho('an1', '10', {'queixa': 'x'}), contains('autor'));
      expect(c.repo.atualizarRascunho('an1', '3', {'dor': '99'}), contains('Dor'));
      expect(c.repo.atualizarRascunho('an1', '3', {'queixa': 'Nova queixa', 'gestante': 'sim'}), isNull);
      expect(c.repo.porId('an1')!.respostas['queixa'], 'Nova queixa');
      expect(c.repo.descartarRascunho('an1', '10'), contains('autor'));
      expect(c.repo.descartarRascunho('an1', '3'), isNull);
      expect(c.repo.anamnesesDoPaciente('p1'), isEmpty);
    });

    test('assinar exige as obrigatórias, só o autor, e gera selo', () {
      final c = montar();
      c.repo.adicionarAnamnese(anamnese(respostas: {'queixa': 'Dor'}));
      expect(c.repo.assinarAnamnese('an1', '3'), contains('Gestante?'));
      expect(c.repo.assinarAnamnese('an1', '10'), contains('autor'));
      c.repo.atualizarRascunho('an1', '3', {'queixa': 'Dor', 'gestante': 'nao'});
      expect(c.repo.assinarAnamnese('an1', '3', agora: DateTime(2030, 1, 7, 10)), isNull);
      final a = c.repo.porId('an1')!;
      expect(a.assinada, isTrue);
      expect(a.selo, isNotNull);
      expect(a.assinadaEm, DateTime(2030, 1, 7, 10));
      expect(c.repo.assinarAnamnese('an1', '3'), contains('já assinada'));
    });

    test('assinada não pode ser alterada nem excluída', () {
      final c = montar();
      c.repo.adicionarAnamnese(anamnese());
      c.repo.assinarAnamnese('an1', '3');
      expect(c.repo.atualizarRascunho('an1', '3', {'queixa': 'x'}), contains('RN05'));
      expect(c.repo.descartarRascunho('an1', '3'), contains('RN05'));
      expect(c.repo.porId('an1')!.respostas['queixa'], 'Dor no 26');
    });

    test('nova versão: só de assinada, mesmo autor e modelo, uma vez; histórico mantido', () {
      final c = montar();
      c.repo.adicionarAnamnese(anamnese());
      expect(c.repo.adicionarAnamnese(anamnese(id: 'an2', anterior: 'an1')), contains('rascunho'));
      c.repo.assinarAnamnese('an1', '3');

      expect(c.repo.adicionarAnamnese(anamnese(id: 'an2', anterior: 'zzz')), contains('não encontrada'));
      expect(c.repo.adicionarAnamnese(anamnese(id: 'an2', anterior: 'an1', modelo: 'outro')),
          contains('mesmo modelo'));
      expect(c.repo.adicionarAnamnese(anamnese(id: 'an2', anterior: 'an1', prof: '10')),
          contains('autor'));
      expect(c.repo.adicionarAnamnese(anamnese(id: 'an2', anterior: 'an1', respostas: {
        'queixa': 'Nova dor',
        'gestante': 'nao',
      })), isNull);
      c.repo.assinarAnamnese('an2', '3');

      expect(c.repo.adicionarAnamnese(anamnese(id: 'an3', anterior: 'an1')), contains('já foi atualizada'));
      expect(c.repo.anamnesesDoPaciente('p1').map((a) => a.id), ['an2', 'an1']);
      expect(c.repo.substituidas('p1'), {'an1'});
      expect(c.repo.porId('an1')!.respostas['queixa'], 'Dor no 26');
    });

    test('avisa os ouvintes só quando muda', () {
      final c = montar();
      var chamadas = 0;
      c.repo.addListener(() => chamadas++);
      c.repo.adicionarAnamnese(anamnese());
      c.repo.adicionarAnamnese(anamnese()); // duplicada: não notifica
      c.repo.assinarAnamnese('an1', '3');
      expect(chamadas, 2);
    });
  });

    group('Perguntas condicionais e seções', () {
    const mae = PerguntaAnamnese(id: 'm', enunciado: 'M', tipo: TipoResposta.simNao);
    const filha = PerguntaAnamnese(
        id: 'f', enunciado: 'F', tipo: TipoResposta.texto, obrigatoria: true, dependeDe: 'm');
    const porOpcao = PerguntaAnamnese(
        id: 'x', enunciado: 'X', tipo: TipoResposta.texto, dependeDe: 'a', dependeValor: 'B|C');

    test('sem dependência a pergunta sempre aparece', () {
      expect(perguntaVisivel(mae, {}), isTrue);
    });

    test('a filha só aparece quando a mãe é "sim" (padrão)', () {
      expect(perguntaVisivel(filha, {}), isFalse);
      expect(perguntaVisivel(filha, {'m': 'nao'}), isFalse);
      expect(perguntaVisivel(filha, {'m': 'sim'}), isTrue);
    });

    test('dependeValor aceita várias opções, também em múltipla escolha', () {
      expect(perguntaVisivel(porOpcao, {'a': 'B'}), isTrue);
      expect(perguntaVisivel(porOpcao, {'a': 'D|C'}), isTrue);
      expect(perguntaVisivel(porOpcao, {'a': 'D'}), isFalse);
      expect(perguntaVisivel(porOpcao, {}), isFalse);
    });

    test('obrigatória oculta não trava a assinatura', () {
      expect(faltandoObrigatorias([mae, filha], {'m': 'nao'}), isEmpty);
      expect(faltandoObrigatorias([mae, filha], {'m': 'sim'}), ['F']);
      expect(faltandoObrigatorias([mae, filha], {'m': 'sim', 'f': 'ok'}), isEmpty);
    });

    test('modelo odontológico: dois níveis, dependências coerentes e nada obrigatório', () {
      final m = modelosAnamnesePadrao.firstWhere((x) => x.id == 'anamnese-odontologica');
      final ids = <String>{};
      for (final p in m.perguntas) {
        if (p.dependeDe != null) {
          expect(ids.contains(p.dependeDe), isTrue, reason: '${p.id} depende de ${p.dependeDe}');
        }
        ids.add(p.id);
      }
      expect(m.perguntas.every((p) => (p.secao ?? '').contains('|')), isTrue);
      expect(m.perguntas.map((p) => p.secao!.split('|').first).toSet(), {'Anamnese', 'Exame físico'});
      expect(m.perguntas.where((p) => p.obrigatoria), isEmpty);
    });

    test('a ficha odontológica vazia ou parcial já pode ser salva', () {
      final m = modelosAnamnesePadrao.firstWhere((x) => x.id == 'anamnese-odontologica');
      expect(faltandoObrigatorias(m.perguntas, {}), isEmpty);
      expect(validarRespostas(m.perguntas, {'queixa': 'Dor no 26', 'tratamento_medico': 'sim'}), isNull);
    });
  });
}