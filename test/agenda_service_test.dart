import 'package:flutter_test/flutter_test.dart';
import 'package:ibn/features/agenda/data/agenda_service.dart';
import 'package:ibn/features/agenda/domain/agendamento.dart';
import 'package:ibn/features/pacientes/data/paciente_repository.dart';

/// Monta um agendamento de teste em 07/01/2030 (data sem agendamentos de exemplo).
Agendamento ag({
  required String id,
  required String prof,
  required int sala,
  required String proc,
  required int hora,
  int min = 0,
  int dur = 30,
  String paciente = 'p1',
}) {
  final inicio = DateTime(2030, 1, 7, hora, min);
  return Agendamento(
    id: id,
    pacienteId: paciente,
    profissionalId: prof,
    salaNumero: sala,
    procedimentoId: proc,
    inicio: inicio,
    fim: inicio.add(Duration(minutes: dur)),
  );
}

void main() {
  group('AgendaService - conflitos (RN01 e RN02)', () {
    late AgendaService servico;
    setUp(() => servico = AgendaService(comExemplos: false));

    test('aceita um agendamento válido', () {
      final erro = servico.criar(
          ag(id: '1', prof: '3', sala: 3, proc: 'consulta-odontologica', hora: 9));
      expect(erro, isNull);
    });

    test('recusa a mesma sala em horário sobreposto (RN02)', () {
      servico.criar(ag(id: '1', prof: '3', sala: 3, proc: 'consulta-odontologica', hora: 9));
      // Outro dentista (Dra. Lúcia), mesma sala, 09:15
      final erro = servico.criar(
          ag(id: '2', prof: '10', sala: 3, proc: 'consulta-odontologica', hora: 9, min: 15));
      expect(erro, contains('ocupada'));
    });

    test('recusa o mesmo profissional em outra sala no mesmo horário (RN02)', () {
      servico.criar(ag(id: '1', prof: '5', sala: 1, proc: 'consulta-medica', hora: 9));
      final erro = servico.criar(
          ag(id: '2', prof: '5', sala: 2, proc: 'consulta-medica', hora: 9, min: 15));
      expect(erro, contains('já tem atendimento'));
    });

    test('Sala 3 não aceita medicina (RN01)', () {
      final erro = servico.criar(
          ag(id: '1', prof: '5', sala: 3, proc: 'consulta-medica', hora: 9));
      expect(erro, contains('RN01'));
    });

    test('Sala 4 não aceita odontologia (RN01)', () {
      final erro = servico.criar(
          ag(id: '1', prof: '3', sala: 4, proc: 'consulta-odontologica', hora: 9));
      expect(erro, contains('RN01'));
    });

    test('profissional só realiza a própria especialidade', () {
      // Dentista tentando uma consulta médica na Sala 1
      final erro = servico.criar(
          ag(id: '1', prof: '3', sala: 1, proc: 'consulta-medica', hora: 9));
      expect(erro, contains('não realiza'));
    });

    test('horários que apenas encostam não conflitam', () {
      servico.criar(ag(id: '1', prof: '5', sala: 1, proc: 'consulta-medica', hora: 9));
      final erro = servico.criar(
          ag(id: '2', prof: '5', sala: 1, proc: 'consulta-medica', hora: 9, min: 30));
      expect(erro, isNull);
    });

    test('Faltou/Desmarcou libera o horário', () {
      servico.criar(ag(id: '1', prof: '5', sala: 1, proc: 'consulta-medica', hora: 9));
      servico.mudarStatus('1', StatusAgendamento.faltouDesmarcou);
      final erro = servico.criar(
          ag(id: '2', prof: '5', sala: 1, proc: 'consulta-medica', hora: 9));
      expect(erro, isNull);
    });

    test('agendar vincula o paciente ao profissional escolhido (RN03)', () {
      servico.criar(ag(
          id: '1', prof: '10', sala: 3, proc: 'consulta-odontologica', hora: 11, paciente: 'p3'));
      final p = pacientes.buscarPorId('p3')!;
      expect(p.profissionaisVinculados, contains('10'));
    });
  });
}