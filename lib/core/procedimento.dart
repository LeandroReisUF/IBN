import 'package:ibn/core/especialidade.dart';
import 'package:ibn/features/configuracoes/data/configuracao_repository.dart';

/// Procedimento ou tipo de consulta que pode ser agendado.
class Procedimento {
  final String id;
  final String nome;
  final Set<Especialidade> especialidades;
  final int duracaoMinutos;
  final bool ativo;

  const Procedimento({
    required this.id,
    required this.nome,
    required this.especialidades,
    required this.duracaoMinutos,
    this.ativo = true,
  });

  /// Alguma das áreas deste procedimento coincide com [areas]?
  /// Serve para profissional (áreas do perfil) e para sala (áreas permitidas).
  bool aceitaAlgumaDe(Set<Especialidade> areas) => especialidades.any(areas.contains);

  String get rotuloAreas => especialidades.map((e) => e.rotulo).join(', ');

  Procedimento copiarCom({
    String? nome,
    Set<Especialidade>? especialidades,
    int? duracaoMinutos,
    bool? ativo,
  }) =>
      Procedimento(
        id: id,
        nome: nome ?? this.nome,
        especialidades: especialidades ?? this.especialidades,
        duracaoMinutos: duracaoMinutos ?? this.duracaoMinutos,
        ativo: ativo ?? this.ativo,
      );
}

/// Procedimentos que o código chama pelo id: não podem ser excluídos nem desativados.
const Set<String> procedimentosDoSistema = {'manutencao-ortodontica'};


/// Catálogo PROVISÓRIO (depois virá do cadastro/servidor).
const List<Procedimento> procedimentosPadrao = [
  Procedimento(id: 'consulta-medica', nome: 'Consulta médica', especialidades: {Especialidade.medicina}, duracaoMinutos: 30),
  Procedimento(id: 'consulta-enfermagem', nome: 'Consulta de enfermagem', especialidades: {Especialidade.enfermagem}, duracaoMinutos: 30),
  Procedimento(id: 'sessao-fisioterapia', nome: 'Sessão de fisioterapia', especialidades: {Especialidade.fisioterapia}, duracaoMinutos: 50),
  Procedimento(id: 'consulta-nutricional', nome: 'Consulta nutricional', especialidades: {Especialidade.nutricao}, duracaoMinutos: 45),
  Procedimento(id: 'sessao-psicologia', nome: 'Sessão de psicologia', especialidades: {Especialidade.psicologia}, duracaoMinutos: 50),
  Procedimento(id: 'consulta-odontologica', nome: 'Consulta odontológica', especialidades: {Especialidade.odontologia}, duracaoMinutos: 30),
  Procedimento(id: 'profilaxia', nome: 'Profilaxia (limpeza)', especialidades: {Especialidade.odontologia}, duracaoMinutos: 40),
  Procedimento(id: 'restauracao', nome: 'Restauração', especialidades: {Especialidade.odontologia}, duracaoMinutos: 60),
  // Ortodontia (Fase E)
  Procedimento(id: 'instalacao-aparelho', nome: 'Instalação de aparelho ortodôntico', especialidades: {Especialidade.odontologia}, duracaoMinutos: 90),
  Procedimento(id: 'manutencao-ortodontica', nome: 'Manutenção ortodôntica', especialidades: {Especialidade.odontologia}, duracaoMinutos: 30),
  Procedimento(id: 'remocao-aparelho', nome: 'Remoção de aparelho ortodôntico', especialidades: {Especialidade.odontologia}, duracaoMinutos: 60),
  Procedimento(id: 'moldagem-escaneamento', nome: 'Moldagem / escaneamento ortodôntico', especialidades: {Especialidade.odontologia}, duracaoMinutos: 45),
  Procedimento(id: 'toxina-botulinica', nome: 'Toxina botulínica', especialidades: {Especialidade.harmonizacaoOrofacial}, duracaoMinutos: 30),
  Procedimento(id: 'preenchimento', nome: 'Preenchimento facial', especialidades: {Especialidade.harmonizacaoOrofacial}, duracaoMinutos: 45),
  Procedimento(id: 'peeling', nome: 'Peeling', especialidades: {Especialidade.biomedicina}, duracaoMinutos: 60),
  Procedimento(id: 'microagulhamento', nome: 'Microagulhamento', especialidades: {Especialidade.biomedicina}, duracaoMinutos: 60),
  Procedimento(id: 'coleta-exames', nome: 'Coleta de exames', especialidades: {Especialidade.biomedicina}, duracaoMinutos: 20),
];

/// Procedimentos ativos (os que aceitam agendamento e plano novos).
List<Procedimento> get procedimentos => configuracaoClinica.procedimentosAtivos;

Procedimento? buscarProcedimento(String id) => configuracaoClinica.procedimentoPorId(id);