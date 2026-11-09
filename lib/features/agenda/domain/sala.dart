import 'package:ibn/core/especialidade.dart';
import 'package:ibn/features/configuracoes/data/configuracao_repository.dart';

/// Sala física da clínica (RN01).
class Sala {
  final int numero;
  final String nome;
  final bool exclusiva;
  final Set<Especialidade> especialidadesPermitidas;
  final bool ativa;

  const Sala({
    required this.numero,
    required this.nome,
    required this.exclusiva,
    required this.especialidadesPermitidas,
    this.ativa = true,
  });

  bool permiteEspecialidade(Especialidade e) =>
      especialidadesPermitidas.contains(e);

  Sala copiarCom({
    String? nome,
    bool? exclusiva,
    Set<Especialidade>? especialidadesPermitidas,
    bool? ativa,
  }) =>
      Sala(
        numero: numero,
        nome: nome ?? this.nome,
        exclusiva: exclusiva ?? this.exclusiva,
        especialidadesPermitidas: especialidadesPermitidas ?? this.especialidadesPermitidas,
        ativa: ativa ?? this.ativa,
      );
}

const _revezamento = {
  Especialidade.medicina,
  Especialidade.enfermagem,
  Especialidade.fisioterapia,
  Especialidade.nutricao,
  Especialidade.psicologia,
};

/// RN01: salas 1 e 2 em revezamento; sala 3 só Odontologia; sala 4 só Biomedicina.
const List<Sala> salasPadrao = [
  Sala(numero: 1, nome: 'Sala 1', exclusiva: false, especialidadesPermitidas: _revezamento),
  Sala(numero: 2, nome: 'Sala 2', exclusiva: false, especialidadesPermitidas: _revezamento),
  Sala(
    numero: 3,
    nome: 'Sala 3',
    exclusiva: true,
    especialidadesPermitidas: {Especialidade.odontologia, Especialidade.harmonizacaoOrofacial},
  ),
  Sala(
    numero: 4,
    nome: 'Sala 4',
    exclusiva: true,
    especialidadesPermitidas: {Especialidade.biomedicina},
  ),
];

/// Salas ativas (as que aceitam agendamento novo).
List<Sala> get salas => configuracaoClinica.salasAtivas;

Sala? buscarSala(int numero) => configuracaoClinica.salaPorNumero(numero);