import 'package:ibn/features/anamnese/data/anamnese_repository.dart';
import 'package:ibn/features/biomedicina/data/biomedicina_repository.dart';
import 'package:ibn/features/documentos/data/documentos_repository.dart';
import 'package:ibn/features/exames/data/exames_repository.dart';
import 'package:ibn/features/hof/data/hof_repository.dart';
import 'package:ibn/features/odontograma/data/odontograma_repository.dart';
import 'package:ibn/features/ortodontia/domain/ortodontia.dart';
import 'package:ibn/features/pacientes/data/paciente_repository.dart';
import 'package:ibn/features/plano_tratamento/data/plano_repository.dart';

/// Ensina o [PacienteRepository] a perguntar a TODOS os módulos clínicos se o
/// paciente tem registros. Sem isto, só vínculos e atendimentos contavam, e um
/// paciente com anamnese, plano, exame etc. poderia ser excluído (RN05).
///
/// Chame uma vez em `main()` com o repositório do app.
/// ATENÇÃO: no servidor isto vira uma consulta ao banco.
void registrarFontesDeHistorico(PacienteRepository repo) {
  repo.registrarFonteHistorico(hofRepository.temHistorico);
  repo.registrarFonteHistorico(examesRepository.temHistorico);
  repo.registrarFonteHistorico(documentosRepository.temHistorico);
  repo.registrarFonteHistorico(anamneseRepository.temHistorico);
  repo.registrarFonteHistorico(planoRepository.temHistorico);
  repo.registrarFonteHistorico(biomedicinaRepository.temHistorico);
  repo.registrarFonteHistorico((id) =>
      odontogramas.historicoDoPaciente(id).isNotEmpty ||
      odontogramas.historicoMarcasArcada(id).isNotEmpty);
  repo.registrarFonteHistorico((id) =>
      ortodontiaRepository.fichaDoPaciente(id) != null ||
      ortodontiaRepository.manutencoesDoPaciente(id).isNotEmpty ||
      ortodontiaRepository.fotosDoPaciente(id).isNotEmpty);
}