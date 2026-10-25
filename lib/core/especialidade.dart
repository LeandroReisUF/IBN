/// Especialidades atendidas na clínica (RN01).
enum Especialidade {
  medicina('Medicina'),
  enfermagem('Enfermagem'),
  fisioterapia('Fisioterapia'),
  nutricao('Nutrição'),
  psicologia('Psicologia'),
  odontologia('Odontologia'),
  harmonizacaoOrofacial('Harmonização Orofacial'),
  biomedicina('Biomedicina');

  final String rotulo;
  const Especialidade(this.rotulo);
}