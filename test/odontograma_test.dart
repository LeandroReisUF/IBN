import 'package:flutter_test/flutter_test.dart';
import '../lib/core/auth_service.dart';
import '../lib/core/odontograma.dart';
import '../lib/core/odontograma_repository.dart';
import '../lib/core/paciente_repository.dart';
import '../lib/core/politica_acesso_service.dart';

RegistroDente reg(String id, String paciente, int dente, FaceDente? face, SituacaoDente s) =>
    RegistroDente(
      id: id,
      pacienteId: paciente,
      numeroDente: dente,
      face: face,
      situacao: s,
      data: DateTime(2030, 1, 7),
      profissionalId: '3',
    );

void main() {
  group('Odontograma', () {
    late OdontogramaRepository repo;
    setUp(() => repo = OdontogramaRepository(comExemplos: false));

    test('o último registro de uma face prevalece', () {
      repo.adicionar(reg('1', 'p1', 16, FaceDente.oclusal, SituacaoDente.planejado));
      repo.adicionar(reg('2', 'p1', 16, FaceDente.oclusal, SituacaoDente.realizado));
      final atual = repo.estadoAtual('p1')[RegistroDente.chave(16, FaceDente.oclusal)]!;
      expect(atual.situacao, SituacaoDente.realizado);
    });

    test('o histórico guarda tudo, do mais recente ao mais antigo', () {
      repo.adicionar(reg('1', 'p1', 16, FaceDente.oclusal, SituacaoDente.planejado));
      repo.adicionar(reg('2', 'p1', 16, FaceDente.oclusal, SituacaoDente.realizado));
      final historico = repo.historicoDoPaciente('p1');
      expect(historico.map((r) => r.id).toList(), ['2', '1']);
    });

    test('pacientes diferentes não se misturam', () {
      repo.adicionar(reg('1', 'p1', 36, null, SituacaoDente.ausente));
      expect(repo.estadoAtual('p2'), isEmpty);
    });

    test('dente ausente pode ser revertido com um novo registro', () {
      repo.adicionar(reg('1', 'p1', 36, null, SituacaoDente.ausente));
      repo.adicionar(reg('2', 'p1', 36, null, SituacaoDente.existente));
      final atual = repo.estadoAtual('p1')[RegistroDente.chave(36, null)]!;
      expect(atual.situacao, SituacaoDente.existente);
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