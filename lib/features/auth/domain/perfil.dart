import 'package:ibn/core/especialidade.dart';

/// Perfis de acesso do sistema (RF01.1).
enum Perfil {
  administrador('Administrador'),
  recepcionista('Recepcionista'),
  dentista('Dentista'),
  biomedico('Biomédico'),
  medico('Médico'),
  enfermeiro('Enfermeiro'),
  fisioterapeuta('Fisioterapeuta'),
  nutricionista('Nutricionista'),
  psicologo('Psicólogo');

  final String rotulo;
  const Perfil(this.rotulo);

  /// Recepção e Administração veem a clínica toda (RN03).
  bool get veClinicaInteira =>
      this == Perfil.administrador || this == Perfil.recepcionista;

  /// Especialidades que este perfil pode atender (usado na agenda, RF02.1).
  Set<Especialidade> get especialidades => switch (this) {
        Perfil.administrador || Perfil.recepcionista => const <Especialidade>{},
        Perfil.dentista => const {
            Especialidade.odontologia,
            Especialidade.harmonizacaoOrofacial,
          },
        Perfil.biomedico => const {Especialidade.biomedicina},
        Perfil.medico => const {Especialidade.medicina},
        Perfil.enfermeiro => const {Especialidade.enfermagem},
        Perfil.fisioterapeuta => const {Especialidade.fisioterapia},
        Perfil.nutricionista => const {Especialidade.nutricao},
        Perfil.psicologo => const {Especialidade.psicologia},
      };
}