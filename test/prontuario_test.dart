import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/features/pacientes/domain/paciente.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/core/politica_acesso_service.dart';
import 'package:ibn/features/prontuario/domain/prontuario.dart';
import 'package:ibn/features/prontuario/data/prontuario_repository.dart';
import 'package:ibn/features/auth/domain/usuario.dart';

Atendimento atend({String id = 'a1', String prof = '3', String pac = 'p1'}) => Atendimento(
      id: id,
      pacienteId: pac,
      profissionalId: prof,
      inicio: DateTime(2026, 10, 28, 9),
    );

Evolucao evo({
  String id = 'e1',
  String atendimento = 'a1',
  String prof = '3',
  String texto = 'Paciente relata dor no 26.',
  bool assinada = false,
}) =>
    Evolucao(
      id: id,
      atendimentoId: atendimento,
      pacienteId: 'p1',
      profissionalId: prof,
      tipo: TipoEvolucao.livre,
      texto: texto,
      dataHora: DateTime(2026, 10, 28, 9, 10),
      assinada: assinada,
    );

Adendo adendo({
  String id = 'ad1',
  String evolucao = 'e1',
  String prof = '3',
  String justificativa = 'Erro de digitação',
  String texto = 'Leia-se dente 16.',
}) =>
    Adendo(
      id: id,
      evolucaoId: evolucao,
      pacienteId: 'p1',
      profissionalId: prof,
      justificativa: justificativa,
      texto: texto,
      dataHora: DateTime(2026, 10, 29, 8),
    );

/// Repositório com um atendimento aberto (a1) do profissional 3.
ProntuarioRepository comAtendimento() {
  final r = ProntuarioRepository();
  expect(r.iniciarAtendimento(atend()), isNull);
  return r;
}

void main() {
  group('Atendimento', () {
    test('inicia e aparece como ativo', () {
      final r = comAtendimento();
      expect(r.atendimentoAtivo('p1', '3')!.id, 'a1');
      expect(r.temHistorico('p1'), isTrue);
      expect(r.temHistorico('p2'), isFalse);
    });

    test('não permite dois atendimentos abertos do mesmo profissional com o mesmo paciente', () {
      final r = comAtendimento();
      expect(r.iniciarAtendimento(atend(id: 'a2')), isNotNull);
    });

    test('outro profissional pode atender o mesmo paciente', () {
      final r = comAtendimento();
      expect(r.iniciarAtendimento(atend(id: 'a2', prof: '10')), isNull);
    });

    test('cada profissional vê só os próprios atendimentos', () {
      final r = comAtendimento();
      r.iniciarAtendimento(atend(id: 'a2', prof: '10'));
      expect(r.atendimentosDoPaciente('p1', profissionalId: '3').map((a) => a.id), ['a1']);
      expect(r.atendimentosDoPaciente('p1').length, 2);
    });

    test('encerrar é bloqueado com rascunho pendente', () {
      final r = comAtendimento();
      r.adicionarEvolucao(evo());
      expect(r.encerrarAtendimento('a1', '3'), isNotNull);
      expect(r.atendimentoPorId('a1')!.encerrado, isFalse);
    });

    test('encerra depois de assinar e guarda observação e hora', () {
      final r = comAtendimento();
      r.adicionarEvolucao(evo());
      r.assinarEvolucao('e1', '3');
      final fim = DateTime(2026, 10, 28, 10);
      expect(r.encerrarAtendimento('a1', '3', observacoes: ' ok ', agora: fim), isNull);
      final a = r.atendimentoPorId('a1')!;
      expect(a.encerrado, isTrue);
      expect(a.fim, fim);
      expect(a.observacoesEncerramento, 'ok');
    });

    test('só quem iniciou encerra, e não encerra duas vezes', () {
      final r = comAtendimento();
      expect(r.encerrarAtendimento('a1', '10'), isNotNull);
      expect(r.encerrarAtendimento('a1', '3'), isNull);
      expect(r.encerrarAtendimento('a1', '3'), isNotNull);
    });
  });

  group('Evolução (RN05)', () {
    test('adiciona como rascunho', () {
      final r = comAtendimento();
      expect(r.adicionarEvolucao(evo()), isNull);
      expect(r.evolucoesDoAtendimento('a1').single.assinada, isFalse);
    });

    test('recusa texto vazio, autor errado, atendimento inexistente e duplicada', () {
      final r = comAtendimento();
      expect(r.adicionarEvolucao(evo(texto: '  ')), isNotNull);
      expect(r.adicionarEvolucao(evo(prof: '10')), isNotNull);
      expect(r.adicionarEvolucao(evo(atendimento: 'zzz')), isNotNull);
      expect(r.adicionarEvolucao(evo(assinada: true)), isNotNull);
      expect(r.adicionarEvolucao(evo()), isNull);
      expect(r.adicionarEvolucao(evo()), isNotNull);
    });

    test('rascunho pode ser editado; assinada não', () {
      final r = comAtendimento();
      r.adicionarEvolucao(evo());
      expect(r.atualizarRascunho('e1', '3', 'Texto novo'), isNull);
      expect(r.evolucoesDoAtendimento('a1').single.texto, 'Texto novo');
      expect(r.atualizarRascunho('e1', '10', 'Invasor'), isNotNull);

      r.assinarEvolucao('e1', '3');
      expect(r.atualizarRascunho('e1', '3', 'Tentativa'), isNotNull);
      expect(r.evolucoesDoAtendimento('a1').single.texto, 'Texto novo');
    });

    test('rascunho pode ser descartado; assinada não pode ser excluída', () {
      final r = comAtendimento();
      r.adicionarEvolucao(evo());
      r.adicionarEvolucao(evo(id: 'e2'));
      expect(r.descartarRascunho('e1', '3'), isNull);
      r.assinarEvolucao('e2', '3');
      expect(r.descartarRascunho('e2', '3'), isNotNull);
      expect(r.evolucoesDoAtendimento('a1').map((e) => e.id), ['e2']);
    });

    test('só o autor assina e não assina duas vezes', () {
      final r = comAtendimento();
      r.adicionarEvolucao(evo());
      expect(r.assinarEvolucao('e1', '10'), isNotNull);
      expect(r.assinarEvolucao('e1', '3', agora: DateTime(2026, 10, 28, 9, 30)), isNull);
      final e = r.evolucoesDoAtendimento('a1').single;
      expect(e.assinada, isTrue);
      expect(e.selo, isNotNull);
      expect(e.assinadaEm, DateTime(2026, 10, 28, 9, 30));
      expect(r.assinarEvolucao('e1', '3'), isNotNull);
    });

    test('atendimento encerrado não recebe evolução nova', () {
      final r = comAtendimento();
      r.encerrarAtendimento('a1', '3');
      expect(r.adicionarEvolucao(evo()), isNotNull);
    });
  });

  group('Adendo (RN05)', () {
    ProntuarioRepository comEvolucaoAssinada() {
      final r = comAtendimento();
      r.adicionarEvolucao(evo());
      r.assinarEvolucao('e1', '3');
      return r;
    }

    test('só vale para evolução assinada', () {
      final r = comAtendimento();
      r.adicionarEvolucao(evo());
      expect(r.adicionarAdendo(adendo()), isNotNull);
    });

    test('nasce assinado e não altera a evolução original', () {
      final r = comEvolucaoAssinada();
      final antes = r.evolucoesDoAtendimento('a1').single;
      expect(r.adicionarAdendo(adendo()), isNull);
      final ad = r.adendosDaEvolucao('e1').single;
      expect(ad.assinado, isTrue);
      expect(ad.selo, isNotNull);
      final depois = r.evolucoesDoAtendimento('a1').single;
      expect(depois.texto, antes.texto);
      expect(depois.selo, antes.selo);
    });

    test('funciona depois que o atendimento foi encerrado', () {
      final r = comEvolucaoAssinada();
      r.encerrarAtendimento('a1', '3');
      expect(r.adicionarAdendo(adendo()), isNull);
    });

    test('exige justificativa, texto, autor da evolução e evolução existente', () {
      final r = comEvolucaoAssinada();
      expect(r.adicionarAdendo(adendo(justificativa: 'a')), isNotNull);
      expect(r.adicionarAdendo(adendo(texto: ' ')), isNotNull);
      expect(r.adicionarAdendo(adendo(prof: '10')), isNotNull);
      expect(r.adicionarAdendo(adendo(evolucao: 'zzz')), isNotNull);
      expect(r.adendosDaEvolucao('e1'), isEmpty);
    });
  });

  group('Notificação', () {
    test('avisa os ouvintes a cada mudança', () {
      final r = ProntuarioRepository();
      var chamadas = 0;
      r.addListener(() => chamadas++);
      r.iniciarAtendimento(atend());
      r.adicionarEvolucao(evo());
      r.assinarEvolucao('e1', '3');
      expect(chamadas, 3);
    });
  });

  group('Política: retorno do próprio paciente', () {
    Paciente paciente(Set<String> vinculados) => Paciente(
          id: 'p1',
          nome: 'Maria',
          cpf: '52998224725',
          dataNascimento: DateTime(1985, 3, 12),
          telefone: '81987654321',
          termoLgpd: TermoLGPD(aceitoEm: DateTime(2026, 9, 2), versao: versaoTermoLgpd),
          profissionaisVinculados: vinculados,
        );
    Usuario usuario(String id, Perfil perfil) =>
        Usuario(id: id, nome: 'U$id', email: 'u$id@x', perfil: perfil);

    test('dentista vinculado pode; dentista sem vínculo não', () {
      expect(politicaAcesso.podeAgendarRetorno(usuario('3', Perfil.dentista), paciente({'3'})), isTrue);
      expect(politicaAcesso.podeAgendarRetorno(usuario('10', Perfil.dentista), paciente({'3'})), isFalse);
    });

    test('outros perfis seguem a regra geral', () {
      expect(politicaAcesso.podeAgendarRetorno(usuario('5', Perfil.medico), paciente({'5'})), isFalse);
      expect(politicaAcesso.podeAgendarRetorno(usuario('2', Perfil.recepcionista), paciente({})), isFalse);
      expect(politicaAcesso.podeAgendar(usuario('2', Perfil.recepcionista)), isTrue);
    });
  });
}