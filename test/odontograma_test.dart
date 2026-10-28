import 'package:flutter_test/flutter_test.dart';
import '../lib/features/auth/data/auth_service.dart';
import '../lib/core/condicao_odonto.dart';
import '../lib/core/odontograma.dart';
import '../lib/core/odontograma_repository.dart';
import '../lib/core/paciente_repository.dart';
import '../lib/core/politica_acesso_service.dart';

/// Monta um registro de teste. Sem [face] = dente inteiro.
RegistroDente reg(
  String id,
  int dente,
  CondicaoOdonto condicao, {
  String paciente = 'p1',
  FaceDente? face,
  RaizDente? raiz,
  StatusTratamento status = StatusTratamento.existente,
  DateTime? data,
  String? retifica,
}) =>
    RegistroDente(
      id: id,
      pacienteId: paciente,
      numeroDente: dente,
      alvo: raiz != null
          ? AlvoOdonto.raiz
          : (face != null ? AlvoOdonto.face : AlvoOdonto.dente),
      face: face,
      raiz: raiz,
      condicao: condicao,
      status: status,
      data: data ?? DateTime(2030, 1, 7),
      profissionalId: '3',
      retificaId: retifica,
    );

void main() {
  group('Odontograma - estado atual', () {
    late OdontogramaRepository repo;
    setUp(() => repo = OdontogramaRepository(comExemplos: false));

    test('o último registro de uma face prevalece', () {
      repo.adicionar(reg('1', 16, CondicaoOdonto.cariado, face: FaceDente.oclusal));
      repo.adicionar(reg('2', 16, CondicaoOdonto.restaurado, face: FaceDente.oclusal));
      final estado = repo.estadoAtual('p1');
      expect(estado.length, 1);
      expect(estado.values.single.condicao, CondicaoOdonto.restaurado);
    });

    test('no dente inteiro, categorias diferentes convivem', () {
      repo.adicionar(reg('1', 21, CondicaoOdonto.fratura));
      repo.adicionar(reg('2', 21, CondicaoOdonto.coroa));
      final condicoes = repo.estadoAtual('p1').values.map((r) => r.condicao).toSet();
      expect(condicoes, {CondicaoOdonto.fratura, CondicaoOdonto.coroa});
    });

    test('no dente inteiro, dois estados se substituem (ausente → hígido)', () {
      repo.adicionar(reg('1', 36, CondicaoOdonto.ausente));
      repo.adicionar(reg('2', 36, CondicaoOdonto.higido));
      final estado = repo.estadoAtual('p1');
      expect(estado.length, 1);
      expect(estado.values.single.condicao, CondicaoOdonto.higido);
    });

    test('"Nenhum" no dente inteiro limpa as marcações do dente, mas não as faces', () {
      repo.adicionar(reg('1', 21, CondicaoOdonto.coroa));
      repo.adicionar(reg('2', 21, CondicaoOdonto.fratura));
      repo.adicionar(reg('3', 21, CondicaoOdonto.cariado, face: FaceDente.mesial));
      repo.adicionar(reg('4', 21, CondicaoOdonto.nenhum));
      final estado = repo.estadoAtual('p1').values.toList();
      expect(estado.length, 1);
      expect(estado.single.face, FaceDente.mesial);
    });

    test('pacientes diferentes não se misturam', () {
      repo.adicionar(reg('1', 36, CondicaoOdonto.ausente));
      expect(repo.estadoAtual('p2'), isEmpty);
    });

    test('o histórico guarda tudo, do mais recente ao mais antigo', () {
      repo.adicionar(reg('1', 16, CondicaoOdonto.cariado, face: FaceDente.oclusal));
      repo.adicionar(reg('2', 16, CondicaoOdonto.restaurado, face: FaceDente.oclusal));
      expect(repo.historicoDoPaciente('p1').map((r) => r.id).toList(), ['2', '1']);
    });
  });

  group('Odontograma - retificação (RN05)', () {
    late OdontogramaRepository repo;
    setUp(() => repo = OdontogramaRepository(comExemplos: false));

    test('anular um registro volta ao estado anterior sem apagar o histórico', () {
      repo.adicionar(reg('1', 16, CondicaoOdonto.cariado, face: FaceDente.oclusal));
      repo.adicionar(reg('2', 16, CondicaoOdonto.restaurado, face: FaceDente.oclusal));
      final erro = repo.adicionar(reg('3', 16, CondicaoOdonto.nenhum,
          face: FaceDente.oclusal, retifica: '2'));
      expect(erro, isNull);
      expect(repo.estadoAtual('p1').values.single.condicao, CondicaoOdonto.cariado);
      expect(repo.historicoDoPaciente('p1').length, 3);
      expect(repo.retificados('p1'), {'2'});
    });

    test('retificar com outra condição substitui o registro errado', () {
      repo.adicionar(reg('1', 16, CondicaoOdonto.cariado, face: FaceDente.oclusal));
      repo.adicionar(reg('2', 16, CondicaoOdonto.restaurado,
          face: FaceDente.oclusal, retifica: '1'));
      expect(repo.estadoAtual('p1').values.single.condicao, CondicaoOdonto.restaurado);
    });

    test('um registro só pode ser retificado uma vez', () {
      repo.adicionar(reg('1', 16, CondicaoOdonto.cariado, face: FaceDente.oclusal));
      repo.adicionar(reg('2', 16, CondicaoOdonto.restaurado,
          face: FaceDente.oclusal, retifica: '1'));
      final erro = repo.adicionar(reg('3', 16, CondicaoOdonto.cariado,
          face: FaceDente.oclusal, retifica: '1'));
      expect(erro, contains('já foi retificado'));
    });

    test('recusa retificar registro que não existe ou de outro dente', () {
      repo.adicionar(reg('1', 16, CondicaoOdonto.cariado, face: FaceDente.oclusal));
      expect(
        repo.adicionar(reg('2', 16, CondicaoOdonto.restaurado,
            face: FaceDente.oclusal, retifica: 'xx')),
        contains('não encontrado'),
      );
      expect(
        repo.adicionar(reg('3', 17, CondicaoOdonto.restaurado,
            face: FaceDente.oclusal, retifica: '1')),
        contains('mesmo dente'),
      );
    });
  });

  group('Odontograma - validações', () {
    late OdontogramaRepository repo;
    setUp(() => repo = OdontogramaRepository(comExemplos: false));

    test('recusa condição que não se aplica ao alvo (cárie no dente inteiro)', () {
      final erro = repo.adicionar(reg('1', 16, CondicaoOdonto.cariado));
      expect(erro, contains('não se aplica'));
      expect(repo.historicoDoPaciente('p1'), isEmpty);
    });

    test('recusa ausente numa face', () {
      final erro = repo.adicionar(reg('1', 16, CondicaoOdonto.ausente, face: FaceDente.oclusal));
      expect(erro, contains('não se aplica'));
    });

    test('recusa dente inválido', () {
      expect(repo.adicionar(reg('1', 19, CondicaoOdonto.coroa)), contains('inválido'));
    });

    test('condição de estado não usa status', () {
      final erro = repo.adicionar(
          reg('1', 36, CondicaoOdonto.ausente, status: StatusTratamento.planejado));
      expect(erro, contains('não usa status'));
    });

    test('marcação de raiz exige informar a raiz', () {
      final semRaiz = RegistroDente(
        id: '1',
        pacienteId: 'p1',
        numeroDente: 16,
        alvo: AlvoOdonto.raiz,
        condicao: CondicaoOdonto.tratamentoEndodontico,
        data: DateTime(2030, 1, 7),
        profissionalId: '3',
      );
      expect(repo.adicionar(semRaiz), contains('Escolha a raiz'));
    });
  });

  group('Odontograma - raízes (Fase C)', () {
    late OdontogramaRepository repo;
    setUp(() => repo = OdontogramaRepository(comExemplos: false));

    test('aceita tratamento de canal em uma raiz que o dente tem', () {
      final erro = repo.adicionar(reg('1', 16, CondicaoOdonto.tratamentoEndodontico,
          raiz: RaizDente.palatina, status: StatusTratamento.realizado));
      expect(erro, isNull);
    });

    test('recusa raiz que o dente não tem (mesial no incisivo)', () {
      final erro = repo.adicionar(reg('1', 11, CondicaoOdonto.tratamentoEndodontico,
          raiz: RaizDente.mesial));
      expect(erro, contains('não tem'));
    });

    test('recusa condição de raiz no dente inteiro ou na face', () {
      expect(repo.adicionar(reg('1', 16, CondicaoOdonto.tratamentoEndodontico)),
          contains('não se aplica'));
      expect(
          repo.adicionar(reg('2', 16, CondicaoOdonto.tratamentoEndodontico,
              face: FaceDente.oclusal)),
          contains('não se aplica'));
    });

    test('cada raiz tem as suas marcações, e condições diferentes convivem', () {
      repo.adicionar(reg('1', 26, CondicaoOdonto.tratamentoEndodontico,
          raiz: RaizDente.mesiovestibular, status: StatusTratamento.realizado));
      repo.adicionar(reg('2', 26, CondicaoOdonto.pinoNucleo,
          raiz: RaizDente.mesiovestibular, status: StatusTratamento.realizado));
      repo.adicionar(reg('3', 26, CondicaoOdonto.lesaoPeriapical, raiz: RaizDente.palatina));
      expect(repo.estadoAtual('p1').length, 3);
    });

    test('planejado → realizado atualiza a mesma condição da raiz', () {
      repo.adicionar(reg('1', 26, CondicaoOdonto.tratamentoEndodontico,
          raiz: RaizDente.palatina, status: StatusTratamento.planejado));
      repo.adicionar(reg('2', 26, CondicaoOdonto.tratamentoEndodontico,
          raiz: RaizDente.palatina, status: StatusTratamento.realizado));
      final estado = repo.estadoAtual('p1').values.toList();
      expect(estado.length, 1);
      expect(estado.single.status, StatusTratamento.realizado);
    });

    test('"Nenhum" em uma raiz limpa só aquela raiz', () {
      repo.adicionar(reg('1', 26, CondicaoOdonto.tratamentoEndodontico,
          raiz: RaizDente.mesiovestibular));
      repo.adicionar(reg('2', 26, CondicaoOdonto.lesaoPeriapical, raiz: RaizDente.palatina));
      repo.adicionar(reg('3', 26, CondicaoOdonto.nenhum, raiz: RaizDente.palatina));
      final raizes = repo.estadoAtual('p1').values.map((r) => r.raiz).toList();
      expect(raizes, [RaizDente.mesiovestibular]);
    });

    test('lesão de furca só em dentes com mais de uma raiz', () {
      expect(repo.adicionar(reg('1', 11, CondicaoOdonto.lesaoFurca)), contains('mais de uma raiz'));
      expect(repo.adicionar(reg('2', 16, CondicaoOdonto.lesaoFurca)), isNull);
    });

    test('retificar uma marcação de raiz exige a mesma raiz', () {
      repo.adicionar(reg('1', 26, CondicaoOdonto.tratamentoEndodontico,
          raiz: RaizDente.palatina));
      final erro = repo.adicionar(reg('2', 26, CondicaoOdonto.nenhum,
          raiz: RaizDente.distovestibular, retifica: '1'));
      expect(erro, contains('mesmo dente'));
    });
  });

  group('Odontograma - decíduos (Fase D)', () {
    late OdontogramaRepository repo;
    setUp(() => repo = OdontogramaRepository(comExemplos: false));

    test('aceita registros em dentes decíduos', () {
      expect(repo.adicionar(reg('1', 54, CondicaoOdonto.cariado, face: FaceDente.oclusal)), isNull);
      expect(repo.adicionar(reg('2', 81, CondicaoOdonto.ausente)), isNull);
    });

    test('recusa número de decíduo inexistente', () {
      expect(repo.adicionar(reg('1', 56, CondicaoOdonto.ausente)), contains('inválido'));
      expect(repo.adicionar(reg('2', 86, CondicaoOdonto.ausente)), contains('inválido'));
    });

    test('pulpotomia só se aplica a decíduos', () {
      expect(repo.adicionar(reg('1', 16, CondicaoOdonto.pulpotomia)), contains('decíduos'));
      expect(repo.adicionar(reg('2', 64, CondicaoOdonto.pulpotomia)), isNull);
    });

    test('molar decíduo superior tem 3 raízes e o inferior tem 2', () {
      expect(
          repo.adicionar(reg('1', 54, CondicaoOdonto.tratamentoEndodontico,
              raiz: RaizDente.palatina)),
          isNull);
      expect(
          repo.adicionar(reg('2', 84, CondicaoOdonto.tratamentoEndodontico,
              raiz: RaizDente.palatina)),
          contains('não tem'));
    });
  });

  group('Odontograma - visões', () {
    late OdontogramaRepository repo;
    setUp(() {
      repo = OdontogramaRepository(comExemplos: false);
      repo.adicionar(reg('1', 16, CondicaoOdonto.restaurado,
          face: FaceDente.oclusal,
          status: StatusTratamento.realizado,
          data: DateTime(2030, 1, 1)));
      repo.adicionar(reg('2', 26, CondicaoOdonto.restaurado,
          face: FaceDente.oclusal,
          status: StatusTratamento.planejado,
          data: DateTime(2030, 2, 1)));
      repo.adicionar(reg('3', 36, CondicaoOdonto.ausente, data: DateTime(2030, 3, 1)));
    });

    test('visão planejado mostra só o que está planejado', () {
      final estado = repo.estadoAtual('p1', visao: VisaoOdontograma.planejado);
      expect(estado.values.map((r) => r.numeroDente).toList(), [26]);
    });

    test('visão realizado mostra só o que está realizado', () {
      final estado = repo.estadoAtual('p1', visao: VisaoOdontograma.realizado);
      expect(estado.values.map((r) => r.numeroDente).toList(), [16]);
    });

    test('visão em uma data mostra o odontograma como estava', () {
      final estado = repo.estadoAtual('p1', ate: DateTime(2030, 2, 15));
      expect(estado.values.map((r) => r.numeroDente).toSet(), {16, 26});
    });

    test('uma retificação feita depois da data não altera aquela data', () {
      repo.adicionar(reg('4', 16, CondicaoOdonto.nenhum,
          face: FaceDente.oclusal, retifica: '1', data: DateTime(2030, 4, 1)));
      final naData = repo.estadoAtual('p1', ate: DateTime(2030, 2, 15));
      final hoje = repo.estadoAtual('p1');
      expect(naData.values.map((r) => r.numeroDente).toSet(), {16, 26});
      expect(hoje.values.map((r) => r.numeroDente).toSet(), {26, 36});
    });
  });

  group('Selo do dente', () {
    test('vence a condição de menor prioridade (ausente antes de coroa)', () {
      final principal = marcaPrincipal([
        reg('1', 21, CondicaoOdonto.coroa),
        reg('2', 21, CondicaoOdonto.ausente),
        reg('3', 21, CondicaoOdonto.cariado, face: FaceDente.mesial),
      ]);
      expect(principal!.condicao, CondicaoOdonto.ausente);
    });

    test('sem marcações, não há selo', () {
      expect(marcaPrincipal([]), isNull);
    });
  });

  group('Catálogo de condições', () {
    test('as siglas não se repetem', () {
      final siglas = CondicaoOdonto.values
          .where((c) => c != CondicaoOdonto.nenhum)
          .map((c) => c.sigla)
          .toList();
      expect(siglas.toSet().length, siglas.length);
    });

    test('toda condição se aplica a pelo menos um alvo', () {
      for (final c in CondicaoOdonto.values) {
        expect(c.alvos, isNotEmpty, reason: c.rotulo);
      }
    });

    test('"Nenhum" vem primeiro em todos os menus', () {
      expect(CondicaoOdonto.paraAlvo(AlvoOdonto.dente).first, CondicaoOdonto.nenhum);
      expect(CondicaoOdonto.paraAlvo(AlvoOdonto.face).first, CondicaoOdonto.nenhum);
    });

    test('pulpotomia aparece só nos menus de dentes decíduos', () {
      expect(CondicaoOdonto.paraAlvo(AlvoOdonto.dente), isNot(contains(CondicaoOdonto.pulpotomia)));
      expect(CondicaoOdonto.paraAlvo(AlvoOdonto.dente, deciduo: true),
          contains(CondicaoOdonto.pulpotomia));
    });

    test('furca aparece só para dentes com mais de uma raiz', () {
      expect(
          CondicaoOdonto.paraAlvo(AlvoOdonto.dente, multirradicular: false),
          isNot(contains(CondicaoOdonto.lesaoFurca)));
      expect(CondicaoOdonto.paraAlvo(AlvoOdonto.dente), contains(CondicaoOdonto.lesaoFurca));
    });

    test('cárie só se aplica a face', () {
      expect(CondicaoOdonto.paraAlvo(AlvoOdonto.dente), isNot(contains(CondicaoOdonto.cariado)));
      expect(CondicaoOdonto.paraAlvo(AlvoOdonto.face), contains(CondicaoOdonto.cariado));
    });
  });

  group('Acesso ao prontuário (RN03)', () {
    // Maria (p1) é atendida pelo Dr. Davi (id 3) e pela nutricionista (id 8).
    final maria = pacientes.buscarPorId('p1')!;

    test('dentista vinculado acessa e edita o odontograma', () {
      final davi = auth.buscarPorId('3')!;
      expect(politicaAcesso.podeAcessarProntuario(davi, maria), isTrue);
      expect(politicaAcesso.podeEditarOdontograma(davi, maria), isTrue);
    });

    test('outro dentista, sem vínculo, não acessa nada', () {
      final lucia = auth.buscarPorId('10')!;
      expect(politicaAcesso.podeAcessarProntuario(lucia, maria), isFalse);
      expect(politicaAcesso.podeEditarOdontograma(lucia, maria), isFalse);
    });

    test('nutricionista vinculada acessa o prontuário, mas não edita o odontograma', () {
      final nutri = auth.buscarPorId('8')!;
      expect(politicaAcesso.podeAcessarProntuario(nutri, maria), isTrue);
      expect(politicaAcesso.podeEditarOdontograma(nutri, maria), isFalse);
    });

    test('recepção não abre prontuário clínico', () {
      final recepcao = auth.buscarPorId('2')!;
      expect(politicaAcesso.podeAcessarProntuario(recepcao, maria), isFalse);
    });
  });
}