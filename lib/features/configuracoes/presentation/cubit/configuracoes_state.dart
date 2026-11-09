import 'package:ibn/features/agenda/domain/sala.dart';
import 'package:ibn/features/configuracoes/domain/bloqueio_agenda.dart';
import 'package:ibn/core/procedimento.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/configuracoes/domain/area_dentista.dart';

/// Estados da tela de Configurações (só Administrador).
sealed class ConfiguracoesState {
  const ConfiguracoesState();
}

final class ConfiguracoesInitial extends ConfiguracoesState {
  const ConfiguracoesInitial();
}

final class ConfiguracoesLoading extends ConfiguracoesState {
  const ConfiguracoesLoading();
}

/// [salas] inclui as desativadas.
final class ConfiguracoesSuccess extends ConfiguracoesState {
  final List<Sala> salas;
  final List<BloqueioAgenda> bloqueios;
  final List<Procedimento> procedimentos;
  final Map<Perfil, int> cores;
  final Map<String, Set<AreaDentista>> areasDentistas;
  const ConfiguracoesSuccess(
      this.salas, this.bloqueios, this.procedimentos, this.cores, this.areasDentistas);
}

final class ConfiguracoesError extends ConfiguracoesState {
  final String mensagem;
  const ConfiguracoesError(this.mensagem);
}