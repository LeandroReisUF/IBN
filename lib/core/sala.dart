import 'especialidade.dart';

/// Sala física da clínica (RN01).
class Sala {
  final int numero;
  final String nome;
  final bool exclusiva;
  final Set<Especialidade> especialidadesPermitidas;

  const Sala({
    required this.numero,
    required this.nome,
    required this.exclusiva,
    required this.especialidadesPermitidas,
  });

  bool permiteEspecialidade(Especialidade e) =>
      especialidadesPermitidas.contains(e);
}

const _revezamento = {
  Especialidade.medicina,
  Especialidade.enfermagem,
  Especialidade.fisioterapia,
  Especialidade.nutricao,
  Especialidade.psicologia,
};

/// RN01: salas 1 e 2 em revezamento; sala 3 só Odontologia; sala 4 só Biomedicina.
const List<Sala> salas = [
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

Sala? buscarSala(int numero) {
  for (final s in salas) {
    if (s.numero == numero) return s;
  }
  return null;
}