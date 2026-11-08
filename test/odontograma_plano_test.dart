import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/features/odontograma/data/odontograma_repository.dart';
import 'package:ibn/features/odontograma/domain/condicao_odonto.dart';
import 'package:ibn/features/odontograma/domain/odontograma.dart';
import 'package:ibn/features/plano_tratamento/domain/odontograma_do_plano.dart';

/// Registro de teste sob a [chave] (id do paciente ou chave de um plano).
RegistroDente reg(
  String id,
  String chave,
  int dente,
  CondicaoOdonto condicao, {
  FaceDente? face,
  String? retifica,
}) =>
    RegistroDente(
      id: id,
      pacienteId: chave,
      numeroDente: dente,
      alvo: face != null ? AlvoOdonto.face : AlvoOdonto.dente,
      face: face,
      condicao: condicao,
      data: DateTime(2030, 1, 7),
      profissionalId: '3',
      retificaId: retifica,
    );

void main() {
  late OdontogramaRepository repo;
  setUp(() => repo = OdontogramaRepository(comExemplos: false));

  test('a chave do plano não se confunde com id de paciente', () {
    expect(chaveOdontogramaDoPlano('pl1'), 'plano:pl1');
    expect(ehChaveOdontogramaDePlano('plano:pl1'), isTrue);
    expect(ehChaveOdontogramaDePlano('p1'), isFalse);
    expect(chaveOdontogramaDoPlano('pl1'), isNot(chaveOdontogramaDoPlano('pl2')));
  });

  test('odontograma clínico e odontograma desejado do plano não se misturam', () {
    final chave = chaveOdontogramaDoPlano('pl1');
    expect(repo.adicionar(reg('o1', 'p1', 36, CondicaoOdonto.ausente)), isNull); // hoje
    expect(repo.adicionar(reg('o2', chave, 36, CondicaoOdonto.coroa)), isNull); // desejado

    final clinico = repo.estadoAtual('p1').values.toList();
    expect(clinico.length, 1);
    expect(clinico.single.condicao, CondicaoOdonto.ausente);

    final desejado = repo.estadoAtual(chave).values.toList();
    expect(desejado.length, 1);
    expect(desejado.single.condicao, CondicaoOdonto.coroa);

    expect(repo.historicoDoPaciente('p1').map((r) => r.id), ['o1']);
    expect(repo.historicoDoPaciente(chave).map((r) => r.id), ['o2']);
  });

  test('cada plano tem o seu odontograma desejado', () {
    final a = chaveOdontogramaDoPlano('pl1');
    final b = chaveOdontogramaDoPlano('pl2');
    repo.adicionar(reg('o1', a, 26, CondicaoOdonto.coroa));
    repo.adicionar(reg('o2', b, 26, CondicaoOdonto.fratura));
    expect(repo.estadoAtual(a).values.single.condicao, CondicaoOdonto.coroa);
    expect(repo.estadoAtual(b).values.single.condicao, CondicaoOdonto.fratura);
  });

  test('as regras valem também no odontograma desejado (condição x alvo, retificação)', () {
    final chave = chaveOdontogramaDoPlano('pl1');
    expect(repo.adicionar(reg('o1', chave, 16, CondicaoOdonto.cariado)), contains('não se aplica'));
    expect(repo.adicionar(reg('o2', chave, 19, CondicaoOdonto.coroa)), contains('inválido'));

    repo.adicionar(reg('o3', chave, 26, CondicaoOdonto.coroa));
    expect(repo.adicionar(reg('o4', chave, 26, CondicaoOdonto.nenhum, retifica: 'o3')), isNull);
    expect(repo.estadoAtual(chave), isEmpty); // anulado, mas o histórico fica
    expect(repo.historicoDoPaciente(chave).length, 2);
    expect(repo.retificados(chave), {'o3'});
  });

  test('não dá para retificar um registro do outro odontograma', () {
    final chave = chaveOdontogramaDoPlano('pl1');
    repo.adicionar(reg('o1', 'p1', 36, CondicaoOdonto.ausente));
    expect(
      repo.adicionar(reg('o2', chave, 36, CondicaoOdonto.coroa, retifica: 'o1')),
      contains('não encontrado'),
    );
    expect(repo.estadoAtual('p1').length, 1);
  });

  test('as marcas de arcada também ficam separadas', () {
    final chave = chaveOdontogramaDoPlano('pl1');
    repo.adicionarMarcaArcada(MarcaArcada(
      id: 'm1',
      pacienteId: chave,
      arcada: ArcadaOdonto.superior,
      tipo: TipoMarcaArcada.aparelhoFixo,
      data: DateTime(2030, 1, 7),
      profissionalId: '3',
    ));
    expect(repo.marcasArcadaAtivas(chave)[ArcadaOdonto.superior], [TipoMarcaArcada.aparelhoFixo]);
    expect(repo.marcasArcadaAtivas('p1')[ArcadaOdonto.superior], isEmpty);
  });
}