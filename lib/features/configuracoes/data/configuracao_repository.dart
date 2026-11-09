import 'package:flutter/foundation.dart';
import 'package:ibn/features/agenda/domain/sala.dart';
import 'package:ibn/features/configuracoes/domain/bloqueio_agenda.dart';
import 'package:ibn/core/procedimento.dart';
import 'package:ibn/features/auth/domain/perfil.dart';
import 'package:ibn/features/configuracoes/domain/paleta_cores.dart';

/// Configurações da clínica em memória (PROVISÓRIO). Hoje: salas e bloqueios.
/// No servidor, as mesmas regras valem por clínica.
class ConfiguracaoRepository extends ChangeNotifier {
      ConfiguracaoRepository({
    List<Sala> salasIniciais = salasPadrao,
    List<Procedimento> procedimentosIniciais = procedimentosPadrao,
  })  : _salas = List.of(salasIniciais),
        _procedimentos = List.of(procedimentosIniciais),
        _coresPerfil = Map.of(_coresPadrao);

  final List<Sala> _salas;
  final List<Procedimento> _procedimentos;
  final Map<Perfil, int> _coresPerfil;

  static const Map<Perfil, int> _coresPadrao = {
    Perfil.dentista: 0xFF1E88E5,
    Perfil.biomedico: 0xFF8E24AA,
    Perfil.medico: 0xFFE53935,
    Perfil.enfermeiro: 0xFFFB8C00,
    Perfil.fisioterapeuta: 0xFF43A047,
    Perfil.nutricionista: 0xFF7CB342,
    Perfil.psicologo: 0xFF3949AB,
  };

  /// Cinza para quem não tem cor própria (Administrador e Recepção).
  static const int corNeutra = 0xFF78909C;

  final List<BloqueioAgenda> _bloqueios = [];
  int _contador = 0;

  String novoId() {
    _contador++;
    return 'cfg${DateTime.now().microsecondsSinceEpoch}$_contador';
  }

  // ---------- salas ----------

  /// Inclui as desativadas (tela de configuração).
  List<Sala> get todasAsSalas => List.of(_salas)..sort((a, b) => a.numero.compareTo(b.numero));

  /// Só as que aceitam agendamento novo.
  List<Sala> get salasAtivas => todasAsSalas.where((s) => s.ativa).toList();

  /// Devolve também a desativada, para o histórico da agenda continuar legível.
  Sala? salaPorNumero(int numero) {
    for (final s in _salas) {
      if (s.numero == numero) return s;
    }
    return null;
  }

  int get proximoNumeroSala =>
      _salas.fold<int>(0, (m, s) => s.numero > m ? s.numero : m) + 1;

  /// Cria (número novo) ou edita (número existente). Devolve o erro, ou null.
  String? salvarSala(Sala s) {
    final nome = s.nome.trim();
    if (nome.isEmpty) return 'Informe o nome da sala.';
    if (s.especialidadesPermitidas.isEmpty) return 'Escolha ao menos uma área para a sala.';
    final repetido = _salas.any(
        (x) => x.numero != s.numero && x.nome.toLowerCase() == nome.toLowerCase());
    if (repetido) return 'Já existe uma sala com este nome.';

    final nova = s.copiarCom(nome: nome);
    final i = _salas.indexWhere((x) => x.numero == s.numero);
    if (i < 0) {
      _salas.add(nova);
    } else {
      _salas[i] = nova;
    }
    notifyListeners();
    return null;
  }

  String? definirSalaAtiva(int numero, bool ativa) {
    final i = _salas.indexWhere((s) => s.numero == numero);
    if (i < 0) return 'Sala não encontrada.';
    _salas[i] = _salas[i].copiarCom(ativa: ativa);
    notifyListeners();
    return null;
  }

  /// [emUso]: a sala já teve agendamentos (quem chama consulta a agenda).
  /// Sala em uso só pode ser desativada, para não perder o histórico.
  String? excluirSala(int numero, {required bool emUso}) {
    if (salaPorNumero(numero) == null) return 'Sala não encontrada.';
    if (emUso) return 'Esta sala já tem agendamentos. Desative-a em vez de excluir.';
    _salas.removeWhere((s) => s.numero == numero);
    _bloqueios.removeWhere((b) => b.salaNumero == numero);
    notifyListeners();
    return null;
  }

  // ---------- bloqueios ----------

  List<BloqueioAgenda> get bloqueios =>
      List.of(_bloqueios)..sort((a, b) => a.inicio.compareTo(b.inicio));

  String? salvarBloqueio(BloqueioAgenda b) {
    if (salaPorNumero(b.salaNumero) == null) return 'Sala não encontrada.';
    if (!b.fim.isAfter(b.inicio)) return 'O fim deve ser depois do início.';
    if (b.motivo.trim().length < 3) return 'Informe o motivo do bloqueio.';
    final i = _bloqueios.indexWhere((x) => x.id == b.id);
    if (i < 0) {
      _bloqueios.add(b);
    } else {
      _bloqueios[i] = b;
    }
    notifyListeners();
    return null;
  }

  /// Desbloquear = excluir o bloqueio.
  String? excluirBloqueio(String id) {
    final antes = _bloqueios.length;
    _bloqueios.removeWhere((b) => b.id == id);
    if (_bloqueios.length == antes) return 'Bloqueio não encontrado.';
    notifyListeners();
    return null;
  }

  /// Primeiro bloqueio da sala que se sobrepõe ao período (só encostar não conta).
  BloqueioAgenda? bloqueioNoPeriodo(int salaNumero, DateTime ini, DateTime fim) {
    for (final b in bloqueios) {
      if (b.salaNumero == salaNumero && ini.isBefore(b.fim) && b.inicio.isBefore(fim)) {
        return b;
      }
    }
    return null;
  }
    // ---------- procedimentos ----------

  /// Inclui os desativados (tela de configuração e histórico).
  List<Procedimento> get todosProcedimentos => List.unmodifiable(_procedimentos);

  List<Procedimento> get procedimentosAtivos =>
      _procedimentos.where((p) => p.ativo).toList();

  /// Devolve também o desativado, para o histórico continuar legível.
  Procedimento? procedimentoPorId(String id) {
    for (final p in _procedimentos) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Cria (id novo) ou edita (id existente). Devolve o erro, ou null.
  String? salvarProcedimento(Procedimento p) {
    final nome = p.nome.trim();
    if (nome.isEmpty) return 'Informe o nome do procedimento.';
    if (p.especialidades.isEmpty) return 'Escolha ao menos uma área para o procedimento.';
    if (p.duracaoMinutos < 5 || p.duracaoMinutos > 480) {
      return 'A duração deve ficar entre 5 e 480 minutos.';
    }
    final repetido = _procedimentos
        .any((x) => x.id != p.id && x.nome.toLowerCase() == nome.toLowerCase());
    if (repetido) return 'Já existe um procedimento com este nome.';

    final novo = p.copiarCom(nome: nome);
    final i = _procedimentos.indexWhere((x) => x.id == p.id);
    if (i < 0) {
      _procedimentos.add(novo);
    } else {
      _procedimentos[i] = novo;
    }
    notifyListeners();
    return null;
  }

  String? definirProcedimentoAtivo(String id, bool ativo) {
    final i = _procedimentos.indexWhere((p) => p.id == id);
    if (i < 0) return 'Procedimento não encontrado.';
    if (!ativo && procedimentosDoSistema.contains(id)) {
      return 'Este procedimento é usado pelo sistema e não pode ser desativado.';
    }
    _procedimentos[i] = _procedimentos[i].copiarCom(ativo: ativo);
    notifyListeners();
    return null;
  }

  /// [emUso]: já aparece em agendamento, plano ou odontograma (quem chama consulta).
  String? excluirProcedimento(String id, {required bool emUso}) {
    if (procedimentoPorId(id) == null) return 'Procedimento não encontrado.';
    if (procedimentosDoSistema.contains(id)) {
      return 'Este procedimento é usado pelo sistema e não pode ser excluído.';
    }
    if (emUso) return 'Este procedimento já foi usado. Desative-o em vez de excluir.';
    _procedimentos.removeWhere((p) => p.id == id);
    notifyListeners();
    return null;
  }
    // ---------- cores por tipo de profissional ----------

  Map<Perfil, int> get coresPerfil => Map.unmodifiable(_coresPerfil);

  int corDoPerfil(Perfil perfil) => _coresPerfil[perfil] ?? corNeutra;

  /// Só tipos de saúde têm cor, da paleta, e duas cores iguais são recusadas
  /// (o objetivo é distinguir os tipos só olhando).
  String? definirCorPerfil(Perfil perfil, int corArgb) {
    if (perfil.especialidades.isEmpty) return 'Só tipos de profissional de saúde têm cor.';
    if (!paletaCoresTag.contains(corArgb)) return 'Escolha uma cor da paleta.';
    final outro = _coresPerfil.entries
        .where((e) => e.key != perfil && e.value == corArgb)
        .firstOrNull;
    if (outro != null) return 'Esta cor já é usada por ${outro.key.rotulo}.';
    _coresPerfil[perfil] = corArgb;
    notifyListeners();
    return null;
  }

  void restaurarCoresPadrao() {
    _coresPerfil
      ..clear()
      ..addAll(_coresPadrao);
    notifyListeners();
  }
}

final configuracaoClinica = ConfiguracaoRepository();