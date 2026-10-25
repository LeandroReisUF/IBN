import 'especialidade.dart';

/// Procedimento ou tipo de consulta que pode ser agendado.
class Procedimento {
  final String id;
  final String nome;
  final Especialidade especialidade;
  final int duracaoMinutos;

  const Procedimento({
    required this.id,
    required this.nome,
    required this.especialidade,
    required this.duracaoMinutos,
  });
}

/// Catálogo PROVISÓRIO (depois virá do cadastro/servidor).
const List<Procedimento> procedimentos = [
  Procedimento(id: 'consulta-medica', nome: 'Consulta médica', especialidade: Especialidade.medicina, duracaoMinutos: 30),
  Procedimento(id: 'consulta-enfermagem', nome: 'Consulta de enfermagem', especialidade: Especialidade.enfermagem, duracaoMinutos: 30),
  Procedimento(id: 'sessao-fisioterapia', nome: 'Sessão de fisioterapia', especialidade: Especialidade.fisioterapia, duracaoMinutos: 50),
  Procedimento(id: 'consulta-nutricional', nome: 'Consulta nutricional', especialidade: Especialidade.nutricao, duracaoMinutos: 45),
  Procedimento(id: 'sessao-psicologia', nome: 'Sessão de psicologia', especialidade: Especialidade.psicologia, duracaoMinutos: 50),
  Procedimento(id: 'consulta-odontologica', nome: 'Consulta odontológica', especialidade: Especialidade.odontologia, duracaoMinutos: 30),
  Procedimento(id: 'profilaxia', nome: 'Profilaxia (limpeza)', especialidade: Especialidade.odontologia, duracaoMinutos: 40),
  Procedimento(id: 'restauracao', nome: 'Restauração', especialidade: Especialidade.odontologia, duracaoMinutos: 60),
  Procedimento(id: 'toxina-botulinica', nome: 'Toxina botulínica', especialidade: Especialidade.harmonizacaoOrofacial, duracaoMinutos: 30),
  Procedimento(id: 'preenchimento', nome: 'Preenchimento facial', especialidade: Especialidade.harmonizacaoOrofacial, duracaoMinutos: 45),
  Procedimento(id: 'peeling', nome: 'Peeling', especialidade: Especialidade.biomedicina, duracaoMinutos: 60),
  Procedimento(id: 'microagulhamento', nome: 'Microagulhamento', especialidade: Especialidade.biomedicina, duracaoMinutos: 60),
  Procedimento(id: 'coleta-exames', nome: 'Coleta de exames', especialidade: Especialidade.biomedicina, duracaoMinutos: 20),
];

Procedimento? buscarProcedimento(String id) {
  for (final p in procedimentos) {
    if (p.id == id) return p;
  }
  return null;
}