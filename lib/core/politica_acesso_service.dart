import 'agendamento.dart';
import 'paciente.dart';
import 'perfil.dart';
import 'usuario.dart';

/// Regras de quem pode ver/fazer o quê (RN03, RF01.3).
///
/// ATENÇÃO: aqui no app é só para esconder telas. Quando existir o
/// servidor, a MESMA regra precisa ser aplicada nele, senão qualquer
/// pessoa técnica conseguiria burlar o app.
class PoliticaAcessoService {
  /// Recepção e Administração veem a lista global de pacientes (RN03).
  bool podeVerListaGlobal(Usuario usuario) => usuario.perfil.veClinicaInteira;

  /// Provisório: só Recepção e Admin cadastram/editam pacientes.
  bool podeEditarPaciente(Usuario usuario) => usuario.perfil.veClinicaInteira;

  /// Inativar/reativar cadastro: Recepção e Admin.
  bool podeInativarPaciente(Usuario usuario) => usuario.perfil.veClinicaInteira;

  /// Exclusão definitiva (só sem histórico): somente Administrador.
  bool podeExcluirPaciente(Usuario usuario) =>
      usuario.perfil == Perfil.administrador;

  /// Vincular/desvincular profissionais de um paciente: Recepção e Admin.
  bool podeVincularProfissional(Usuario usuario) =>
      usuario.perfil.veClinicaInteira;

  /// Criar e editar agendamentos: Recepção e Admin.
  bool podeAgendar(Usuario usuario) => usuario.perfil.veClinicaInteira;

  /// Recepção e Admin veem a agenda da clínica toda; profissionais só a própria.
  bool podeVerAgendaGlobal(Usuario usuario) => usuario.perfil.veClinicaInteira;

  List<Agendamento> filtrarAgenda(Usuario usuario, List<Agendamento> todos) =>
      podeVerAgendaGlobal(usuario)
          ? todos
          : todos.where((a) => a.profissionalId == usuario.id).toList();

  /// Recepção/Admin: qualquer status. Profissional: só nos próprios
  /// atendimentos, e apenas Em atendimento / Atendido.
  List<StatusAgendamento> statusPermitidos(Usuario usuario, Agendamento ag) {
    if (usuario.perfil.veClinicaInteira) return StatusAgendamento.values;
    if (ag.profissionalId == usuario.id) {
      return const [StatusAgendamento.emAtendimento, StatusAgendamento.atendido];
    }
    return const [];
  }

  /// Prontuário clínico: só profissionais de saúde vinculados ao paciente (RN03).
  /// Recepção e Admin não abrem prontuários (regra provisória).
  bool podeAcessarProntuario(Usuario usuario, Paciente paciente) =>
      usuario.perfil.especialidades.isNotEmpty && podeVerPaciente(usuario, paciente);

  /// Odontograma: só dentistas vinculados ao paciente.
  bool podeEditarOdontograma(Usuario usuario, Paciente paciente) =>
      usuario.perfil == Perfil.dentista && podeVerPaciente(usuario, paciente);

  bool podeVerPaciente(Usuario usuario, Paciente paciente) =>
      podeVerListaGlobal(usuario) ||
      paciente.profissionaisVinculados.contains(usuario.id);

  List<Paciente> filtrarPacientes(Usuario usuario, List<Paciente> todos) =>
      todos.where((p) => podeVerPaciente(usuario, p)).toList();
}

final politicaAcesso = PoliticaAcessoService();